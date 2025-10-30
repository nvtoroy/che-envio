import AppKit
import Foundation
import SwiftUI

// MARK: - Data Models
struct TrackingSettings: Codable {
    let trackingNumber: String
    let producto: String
    let pais: String
}

struct TrackingInfo {
    let fullNumber: String
    let tramiteAFIP: String
    let gestionCorreo: String
    let movements: [TrackingMovement]
}

struct TrackingMovement: Identifiable {
    let id = UUID()
    let fecha: String
    let planta: String
    let historia: String
    let estado: String
}

@MainActor
class CorreoCheckViewModel: ObservableObject {
    @Published var trackingNumber: String = "" {
        didSet {
            let sanitized = trackingNumber.filter { $0.isNumber }
            if sanitized != trackingNumber {
                trackingNumber = sanitized
            }
        }
    }
    @Published var producto: String = "" {
        didSet {
            let sanitized = sanitizeLetters(producto)
            if sanitized != producto {
                producto = sanitized
            }
        }
    }
    @Published var pais: String = "" {
        didSet {
            let sanitized = sanitizeLetters(pais)
            if sanitized != pais {
                pais = sanitized
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var trackingInfo: TrackingInfo?
    @Published var hasResult: Bool = false
    @Published var isSuccess: Bool = false
    @Published var statusMessage: String = "Listo para consultar..."
    @Published var lastUpdateTime: String = ""
    @Published var isAutoFillEnabled: Bool = false
    
    private let settingsKey = "CorreoCheckSettings"
    private let apiURL = "https://www.correoargentino.com.ar/sites/all/modules/custom/ca_forms/api/wsFacade.php"
    
    init() {
        loadSettings()
        updateLastUpdateTime()
    }

    // MARK: - Settings Management
    func loadSettings() {
        let userDefaults = UserDefaults.standard
        if let data = userDefaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(TrackingSettings.self, from: data) {
            self.trackingNumber = settings.trackingNumber
            self.producto = settings.producto
            self.pais = settings.pais
        }
    }
    
    func saveSettings() {
        let settings = TrackingSettings(trackingNumber: trackingNumber, producto: producto, pais: pais)
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    // MARK: - Clipboard Handling
    func toggleMode() {
        isAutoFillEnabled.toggle()
    }

    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let textToCopy: String
        if isAutoFillEnabled {
            let components = [producto, trackingNumber, pais].filter { !$0.isEmpty }
            textToCopy = components.joined()
        } else {
            textToCopy = trackingNumber
        }

        guard !textToCopy.isEmpty else { return }
        pasteboard.setString(textToCopy, forType: .string)
    }

    func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        guard let rawString = pasteboard.string(forType: .string) else { return }

        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if isAutoFillEnabled {
            handlePasteWithAutoFill(trimmed)
        } else {
            trackingNumber = trimmed.filter { $0.isNumber }
        }
    }

    // MARK: - API Request
    func checkTracking() {
        guard !trackingNumber.isEmpty && !producto.isEmpty && !pais.isEmpty else {
            statusMessage = "Faltan datos"
            trackingInfo = nil  // Очищаем предыдущие результаты
            updateResult(success: false)
            return
        }
        
        // Валидация формата
        if trackingNumber.count < 8 || !trackingNumber.allSatisfy({ $0.isNumber }) {
            statusMessage = "Número de seguimiento inválido"
            trackingInfo = nil  // Очищаем предыдущие результаты
            updateResult(success: false)
            return
        }
        
        if producto.count != 2 || !producto.allSatisfy({ $0.isLetter }) {
            statusMessage = "Código de producto inválido (debe ser 2 letras)"
            trackingInfo = nil  // Очищаем предыдущие результаты
            updateResult(success: false)
            return
        }
        
        if pais.count != 2 || !pais.allSatisfy({ $0.isLetter }) {
            statusMessage = "Código de país inválido (debe ser 2 letras)"
            trackingInfo = nil  // Очищаем предыдущие результаты
            updateResult(success: false)
            return
        }
        
        isLoading = true
        statusMessage = "Consultando..."
        saveSettings()
        
        guard let url = URL(string: apiURL) else {
            statusMessage = "URL inválida ❌"
            updateResult(success: false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        let bodyString = "action=ondnc&id=\(trackingNumber)&producto=\(producto)&pais=\(pais)"
        request.httpBody = bodyString.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                self.isLoading = false
                self.updateLastUpdateTime()
                
                if error != nil {
                    self.statusMessage = "Error de conexión"
                    self.trackingInfo = nil  // Очищаем предыдущие результаты
                    self.updateResult(success: false)
                    return
                }
                
                guard let data = data else {
                    self.statusMessage = "Sin datos del servidor"
                    self.trackingInfo = nil  // Очищаем предыдущие результаты
                    self.updateResult(success: false)
                    return
                }
                
                // Procesar respuesta HTML
                if let trackingInfo = self.parseHTMLResponse(data: data) {
                    self.trackingInfo = trackingInfo
                    self.updateResult(success: true)
                } else {
                    self.trackingInfo = nil  // Очищаем предыдущие результаты
                    // statusMessage уже установлен в parseHTMLResponse
                    self.updateResult(success: false)
                }
            }
        }.resume()
    }
    
    // MARK: - HTML Parsing
    private func parseHTMLResponse(data: Data) -> TrackingInfo? {
        guard let htmlString = String(data: data, encoding: .utf8) else {
            statusMessage = "Error procesando respuesta"
            return nil
        }
        
        // Проверка на "No se encontraron resultados"
        if htmlString.contains("No se encontraron resultados") {
            statusMessage = "No se encontraron resultados"
            return nil
        }
        
        // Извлечение полного номера (SP-896879735-AR)
        let fullNumber = extractBetween(htmlString, start: "<span class=\"badge\">", end: "</span>") ?? ""
        
        // Извлечение информации AFIP
        let tramiteAFIP = extractBetween(htmlString, start: "<b>Trámite AFIP: </b>", end: "<br>") ?? ""
        
        // Извлечение información Gestión Correo
        let gestionCorreo = extractBetween(htmlString, start: "<b>Gestión Correo Argentino: </b>", end: "<br>") ?? ""
        
        // Парсинг таблицы движений
        var movements: [TrackingMovement] = []
        
        // Ищем все <tr> внутри <tbody>
        let tbodyPattern = "<tbody>(.*?)</tbody>"
        if let tbodyRange = htmlString.range(of: tbodyPattern, options: .regularExpression) {
            let tbody = String(htmlString[tbodyRange])
            
            // Регулярное выражение для извлечения данных из строк таблицы
            // Обратите внимание: нет закрывающего </tr>, строки идут подряд
            let rowPattern = "<tr><td data-title=\"Fecha:\">([^<]+)</td><td data-title=\"Planta:\">([^<]+)</td><td data-title=\"Historia:\">([^<]+)</td><td data-title=\"Estado:\">([^<]*)</td>"
            
            let regex = try? NSRegularExpression(pattern: rowPattern, options: [.dotMatchesLineSeparators])
            let nsString = tbody as NSString
            let matches = regex?.matches(in: tbody, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
            
            print("DEBUG: Found \(matches.count) movements in HTML")
            
            for match in matches {
                if match.numberOfRanges == 5 {
                    let fecha = nsString.substring(with: match.range(at: 1))
                    let planta = nsString.substring(with: match.range(at: 2))
                    let historia = nsString.substring(with: match.range(at: 3))
                    let estado = nsString.substring(with: match.range(at: 4))
                    
                    print("DEBUG: Movement - Fecha: \(fecha), Planta: \(planta), Historia: \(historia)")
                    
                    movements.append(TrackingMovement(
                        fecha: fecha,
                        planta: planta,
                        historia: historia,
                        estado: estado
                    ))
                }
            }
        }
        
        return TrackingInfo(
            fullNumber: fullNumber,
            tramiteAFIP: tramiteAFIP,
            gestionCorreo: gestionCorreo,
            movements: movements
        )
    }
    
    private func extractBetween(_ text: String, start: String, end: String) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[startRange.upperBound..<endRange.lowerBound])
    }
    
    // MARK: - Helper Methods
    private func updateResult(success: Bool) {
        self.isSuccess = success
        self.hasResult = true
        self.statusMessage = success ? "Consulta exitosa ✅" : statusMessage
    }
    
    private func updateLastUpdateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        self.lastUpdateTime = formatter.string(from: Date())
    }

    private func sanitizeLetters(_ text: String) -> String {
        let letters = text.uppercased().filter { $0.isLetter }
        return String(letters.prefix(2))
    }

    private func handlePasteWithAutoFill(_ text: String) {
        let condensed = text.replacingOccurrences(of: "[^A-Za-z0-9]", with: "", options: .regularExpression)

        let digitsOnly = condensed.filter { $0.isNumber }
        guard !digitsOnly.isEmpty else { return }

        if condensed == digitsOnly {
            trackingNumber = digitsOnly
            return
        }

        let prefixLetters = condensed.prefix { $0.isLetter }
        let remainderAfterPrefix = condensed.dropFirst(prefixLetters.count)
        let numericPart = remainderAfterPrefix.prefix { $0.isNumber }
        let suffixPart = remainderAfterPrefix.dropFirst(numericPart.count)

        trackingNumber = String(numericPart)
        producto = String(prefixLetters)
        pais = String(suffixPart)
    }

    func clearFields() {
        producto = ""
        trackingNumber = ""
        pais = ""
    }
}
