import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CorreoCheckViewModel()
    @FocusState private var focusedField: Field?
    private let letterFormatter = AllowedCharactersFormatter(allowed: CharacterSet.letters, maxLength: 2) { $0.uppercased() }
    private let digitsFormatter = AllowedCharactersFormatter(allowed: CharacterSet.decimalDigits)
    @State private var isHistoryPresented = false
    @State private var selectedHistoryCodes: Set<String> = []
    @State private var showHistoryCopyToast = false
    @State private var copyToastMessage = ""
    
    enum Field {
        case producto, trackingNumber, pais, consultar, cerrar
    }

    private final class AllowedCharactersFormatter: Formatter {
    private let allowedCharacters: CharacterSet
    private let maxLength: Int?
    private let transform: (String) -> String

    init(allowed: CharacterSet, maxLength: Int? = nil, transform: @escaping (String) -> String = { $0 }) {
        self.allowedCharacters = allowed
        self.maxLength = maxLength
        self.transform = transform
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func string(for obj: Any?) -> String? {
        guard let string = obj as? String else { return nil }
        return sanitize(string)
    }

    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        obj?.pointee = sanitize(string) as NSString
        return true
    }

    override func isPartialStringValid(_ partialStringPtr: AutoreleasingUnsafeMutablePointer<NSString>, proposedSelectedRange proposedSelRangePtr: NSRangePointer?, originalString: String, originalSelectedRange originalSelRange: NSRange, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        let current = partialStringPtr.pointee as String
        let sanitized = sanitize(current)
        if sanitized != current {
            partialStringPtr.pointee = sanitized as NSString
            proposedSelRangePtr?.pointee = NSRange(location: sanitized.count, length: 0)
        }
        return true
    }

    private func sanitize(_ string: String) -> String {
        let filteredScalars = string.unicodeScalars.filter { allowedCharacters.contains($0) }
        var result = String(filteredScalars)
        result = transform(result)
        if let maxLength = maxLength, result.count > maxLength {
            result = String(result.prefix(maxLength))
        }
        return result
    }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Верхний отступ и заголовок версии
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    
                    // Правая часть с версией в две строки
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Correo Argentino - Seguimiento")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("v1.0 (30/10/2025)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                
                // Горизонтальная черта-отсекатель на всю ширину
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
            }
            
            // Раздел ввода данных
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Número de seguimiento:")
                        Button(action: {
                            isHistoryPresented.toggle()
                        }) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                                .frame(width: 36, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.15))
                                )
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Mostrar historial")
                        .popover(isPresented: $isHistoryPresented, arrowEdge: .bottom) {
                            HistoryPopoverView(
                                viewModel: viewModel,
                                isPresented: $isHistoryPresented,
                                selectedCodes: $selectedHistoryCodes,
                                onSelect: { entry in
                                    applyHistoryEntry(entry)
                                },
                                onCopy: { entry in
                                    handleHistoryCopy(entry)
                                }
                            )
                            .frame(width: 420, height: 320)
                        }
                    }
                    .frame(width: 180, alignment: .leading)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            TextField("SP", value: lettersBinding(\.producto), formatter: letterFormatter)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 40)
                                .multilineTextAlignment(.center)
                                .focused($focusedField, equals: .producto)
                                .onKeyPress(.tab) {
                                    focusedField = .trackingNumber
                                    return .handled
                                }

                            Text("-")
                                .foregroundColor(.secondary)

                            TextField("123456789", value: digitsBinding, formatter: digitsFormatter)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 150)
                                .focused($focusedField, equals: .trackingNumber)
                                .onKeyPress(.tab) {
                                    focusedField = .pais
                                    return .handled
                                }

                            Text("-")
                                .foregroundColor(.secondary)

                            TextField("AR", value: lettersBinding(\.pais), formatter: letterFormatter)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 40)
                                .multilineTextAlignment(.center)
                                .focused($focusedField, equals: .pais)
                                .onKeyPress(.tab) {
                                    focusedField = .consultar
                                    return .handled
                                }
                        }

                        let nothingToCopy = viewModel.isAutoFillEnabled
                            ? (viewModel.producto.isEmpty && viewModel.trackingNumber.isEmpty && viewModel.pais.isEmpty)
                            : viewModel.trackingNumber.isEmpty

                        HStack(spacing: 10) {
                            Button(action: {
                                viewModel.pasteFromClipboard()
                            }) {
                                Image(systemName: "arrow.up.doc")
                                    .font(.system(size: 14))
                                    .frame(width: 36, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.15))
                                    )
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Paste")

                            Button(action: {
                                viewModel.copyToClipboard()
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14))
                                    .frame(width: 36, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(nothingToCopy ? Color.gray.opacity(0.1) : Color.gray.opacity(0.15))
                                    )
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .disabled(nothingToCopy)
                            .accessibilityLabel("Copy")

                            Button(action: {
                                viewModel.toggleMode()
                            }) {
                                Image(systemName: viewModel.isAutoFillEnabled ? "textformat.abc" : "textformat.123")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 36, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.15))
                                    )
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                viewModel.clearFields()
                                focusedField = .producto
                            }) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 14))
                                    .frame(width: 36, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill((viewModel.producto.isEmpty && viewModel.trackingNumber.isEmpty && viewModel.pais.isEmpty) ? Color.gray.opacity(0.1) : Color.gray.opacity(0.15))
                                    )
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.producto.isEmpty && viewModel.trackingNumber.isEmpty && viewModel.pais.isEmpty)
                            .accessibilityLabel("Clear")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer()

                    VStack(spacing: 6) {
                        Button(action: {
                            viewModel.checkTracking()
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(viewModel.isLoading ? "Consultando" : "Consultar")
                                    .foregroundColor(.white)
                            }
                            .frame(width: 130, height: 28)
                            .background(viewModel.isLoading || viewModel.trackingNumber.isEmpty ? Color.gray.opacity(0.5) : Color.blue.opacity(0.7))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .focused($focusedField, equals: .consultar)
                        .disabled(viewModel.isLoading || viewModel.trackingNumber.isEmpty)
                        .onKeyPress(.tab) {
                            focusedField = .cerrar
                            return .handled
                        }

                        Button(action: {
                            viewModel.saveSettings()
                            NSApplication.shared.terminate(nil)
                        }) {
                            Text("Cerrar")
                                .foregroundColor(.white)
                                .frame(width: 130, height: 28)
                                .background(Color.red.opacity(0.7))
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .focused($focusedField, equals: .cerrar)
                        .onKeyPress(.tab) {
                            focusedField = .producto
                            return .handled
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)

            // Раздел результатов
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let trackingInfo = viewModel.trackingInfo {
                        // Информация AFIP y Gestión
                        if !trackingInfo.tramiteAFIP.isEmpty || !trackingInfo.gestionCorreo.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                if !trackingInfo.tramiteAFIP.isEmpty {
                                    HStack(spacing: 4) {
                                        Text("Trámite AFIP:")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(trackingInfo.tramiteAFIP)
                                            .font(.system(size: 12))
                                    }
                                }
                                
                                if !trackingInfo.gestionCorreo.isEmpty {
                                    HStack(spacing: 4) {
                                        Text("Gestión Correo Argentino:")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(trackingInfo.gestionCorreo)
                                            .font(.system(size: 12))
                                    }
                                }
                                
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.gray.opacity(0.3))
                                    .padding(.vertical, 6)
                            }
                        }
                        
                        // Таблица движений
                        if !trackingInfo.movements.isEmpty {
                            VStack(spacing: 0) {
                                // Заголовок таблицы
                                HStack(spacing: 0) {
                                    Text("Fecha")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 110, alignment: .leading)
                                    
                                    Text("Planta")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 180, alignment: .leading)
                                    
                                    Text("Historia")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.15))
                                
                                // Строки таблицы
                                ForEach(trackingInfo.movements) { movement in
                                    HStack(spacing: 0) {
                                        Text(movement.fecha)
                                            .font(.system(size: 11))
                                            .foregroundColor(.black)
                                            .frame(width: 110, alignment: .leading)
                                        
                                        Text(movement.planta)
                                            .font(.system(size: 11))
                                            .foregroundColor(.black)
                                            .frame(width: 180, alignment: .leading)
                                        
                                        HStack(spacing: 4) {
                                            // Иконка статуса
                                            Text(iconForHistoria(movement.historia))
                                                .font(.system(size: 10))
                                            
                                            Text(movement.historia)
                                                .font(.system(size: 11))
                                                .foregroundColor(.black)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .overlay(
                                        Rectangle()
                                            .frame(height: 0.5)
                                            .foregroundColor(.gray.opacity(0.2)),
                                        alignment: .bottom
                                    )
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            
                            // Количество движений
                            Text("Cantidad de movimientos: \(trackingInfo.movements.count)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.top, 6)
                        }
                    } else if viewModel.hasResult && !viewModel.isSuccess {
                        // Сообщение об ошибке
                        VStack(spacing: 8) {
                            Text("❌")
                                .font(.system(size: 40))
                            Text(viewModel.statusMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else if viewModel.hasResult {
                        Text("No se encontró información")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    } else {
                        Text("Ingrese un número de seguimiento y presione Consultar...")
                            .foregroundColor(.gray)
                            .font(.system(size: 13))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
            .frame(minHeight: 200, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
            .border(Color.gray.opacity(0.3), width: 1)
            .padding(.bottom, 5)
            
            // Статус и время
            HStack {
                if viewModel.isSuccess {
                    Text("Estado: Consulta exitosa ✅")
                        .foregroundColor(.secondary)
                } else if viewModel.hasResult {
                    Text("Estado: \(viewModel.statusMessage) ❌")
                        .foregroundColor(.secondary)
                } else {
                    Text("Estado: \(viewModel.statusMessage)")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("Última consulta: \(viewModel.lastUpdateTime)")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            .padding(.horizontal, 20)
            .padding(.top, 5)
            .padding(.bottom, 10)
        }
        .frame(minWidth: 650, maxWidth: 650, minHeight: 500, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if showHistoryCopyToast {
                Text(copyToastMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.75))
                    )
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .overlay(alignment: .topTrailing) {
            // Невидимая кнопка для ESC
            Button(action: {
                viewModel.saveSettings()
                NSApplication.shared.terminate(nil)
            }) {
                EmptyView()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .opacity(0)
        }
        .onAppear {
            // Настройка окна для изменения размера
            if let window = NSApp.windows.first {
                window.styleMask.insert(.resizable)
                window.minSize = NSSize(width: 650, height: 450)
                window.maxSize = NSSize(width: 650, height: 1000)
            }
            
            viewModel.loadSettings()
            focusedField = .trackingNumber
        }
        .onChange(of: focusedField) { _, newValue in
            guard newValue == .trackingNumber, !viewModel.trackingNumber.isEmpty else { return }
            DispatchQueue.main.async {
                (NSApp?.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
            }
        }
        .onDisappear {
            viewModel.saveSettings()
        }
    }

    private func applyHistoryEntry(_ entry: TrackingHistoryEntry) {
        isHistoryPresented = false
        viewModel.producto = entry.left
        viewModel.trackingNumber = entry.digits
        viewModel.pais = entry.right
        selectedHistoryCodes.removeAll()
        DispatchQueue.main.async {
            focusedField = .trackingNumber
        }
    }

    private func handleHistoryCopy(_ entry: TrackingHistoryEntry) {
        viewModel.copyToClipboard(fullCode: entry.code)
        copyToastMessage = "Copiado"
        withAnimation(.easeInOut(duration: 0.2)) {
            showHistoryCopyToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showHistoryCopyToast = false
            }
        }
    }

    private func lettersBinding(_ keyPath: ReferenceWritableKeyPath<CorreoCheckViewModel, String>) -> Binding<String> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { newValue in
                viewModel[keyPath: keyPath] = newValue
            }
        )
    }

    private var digitsBinding: Binding<String> {
        Binding(
            get: { viewModel.trackingNumber },
            set: { newValue in
                viewModel.trackingNumber = newValue
            }
        )
    }

    // Функция для определения иконки на основе истории
    private func iconForHistoria(_ historia: String) -> String {
        let historiaLower = historia.lowercased()
        
        if historiaLower.contains("entregado") || historiaLower.contains("entrega") {
            return "✅"
        } else if historiaLower.contains("llegada") {
            return "📦"
        } else if historiaLower.contains("proceso") || historiaLower.contains("clasificación") {
            return "⚙️"
        } else if historiaLower.contains("tránsito") || historiaLower.contains("transito") {
            return "🚚"
        } else if historiaLower.contains("admitido") {
            return "📥"
        } else {
            return "📌"
        }
    }
}

private struct HistoryPopoverView: View {
    @ObservedObject var viewModel: CorreoCheckViewModel
    @Binding var isPresented: Bool
    @Binding var selectedCodes: Set<String>
    let onSelect: (TrackingHistoryEntry) -> Void
    let onCopy: (TrackingHistoryEntry) -> Void

    private var filteredEntries: [TrackingHistoryEntry] {
        viewModel.filteredHistory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Historial de consultas")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cerrar historial")
            }

            TextField("Buscar o filtrar", text: $viewModel.historySearchTerm)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if filteredEntries.isEmpty {
                VStack(spacing: 6) {
                    Text(viewModel.historyEntries.isEmpty ? "Sin registros todavía" : "Sin coincidencias")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Text("")
                            .frame(width: 24, alignment: .leading)
                            .accessibilityHidden(true)

                        Text("Última verificación")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 140, alignment: .leading)

                        Text("Código")
                            .font(.system(size: 11, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Copiar")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 60, alignment: .center)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.gray.opacity(0.15))

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredEntries) { entry in
                                HistoryRow(
                                    entry: entry,
                                    isSelected: selectionBinding(for: entry),
                                    onSelect: {
                                        onSelect(entry)
                                    },
                                    onCopy: {
                                        onCopy(entry)
                                    },
                                    copyAccessibilityLabel: "Copiar código \(entry.code) completo"
                                )
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
            }

            HStack {
                Button("Limpiar") {
                    viewModel.clearHistory()
                    selectedCodes.removeAll()
                }
                .disabled(viewModel.historyEntries.isEmpty)

                Button("Eliminar seleccionados") {
                    viewModel.deleteHistoryEntries(with: selectedCodes)
                    selectedCodes.removeAll()
                }
                .disabled(selectedCodes.isEmpty)

                Spacer()

                Button("Cerrar") {
                    isPresented = false
                }
            }
            .font(.system(size: 11, weight: .medium))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
        .onDisappear {
            viewModel.historySearchTerm = ""
            selectedCodes.removeAll()
        }
        .onExitCommand {
            isPresented = false
        }
        .onChange(of: viewModel.historyEntries.map(\.code)) { _, codes in
            let existing = Set(codes)
            selectedCodes.formIntersection(existing)
        }
    }

    private func selectionBinding(for entry: TrackingHistoryEntry) -> Binding<Bool> {
        Binding(
            get: {
                selectedCodes.contains(entry.code)
            },
            set: { newValue in
                if newValue {
                    selectedCodes.insert(entry.code)
                } else {
                    selectedCodes.remove(entry.code)
                }
            }
        )
    }

    private struct HistoryRow: View {
        let entry: TrackingHistoryEntry
        @Binding var isSelected: Bool
        let onSelect: () -> Void
        let onCopy: () -> Void
        let copyAccessibilityLabel: String

        var body: some View {
            HStack(spacing: 12) {
                Toggle("", isOn: $isSelected)
                    .labelsHidden()
                    .toggleStyle(CheckboxToggleStyle())
                    .frame(width: 24, alignment: .leading)

                Text(entry.formattedLastCheckedAt)
                    .font(.system(size: 11))
                    .frame(width: 140, alignment: .leading)

                Button(action: onSelect) {
                    Text(entry.code)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .frame(width: 36, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copyAccessibilityLabel)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.clear)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 0.5),
                alignment: .bottom
            )
        }
    }
}
