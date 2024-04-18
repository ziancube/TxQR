//
//  TxQRView.swift
//  Tx-qrcode
//
//  Created by xiaochen on 2024/4/18.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import BigInt


struct TxQRView: View {
    @State private var path = "m/44'/60'/0'/0/0"
    @State private var address = "0xC2F4aC3bb53BEaB6fb656e939526559e6d482E00"
    @State private var nonce = 0.0
    @State private var value = 1.0
    @State private var fee = 0.01
    @State private var limit = 10000.0
    #if os(macOS)
    @State var QR: Image = Image(nsImage: NSImage())
    #elseif os(iOS)
    @State var QR: Image = Image(uiImage: UIImage())
    #endif
    var body: some View {
        VStack {
            Divider()
            labelView("路径") {
                TextField("请输入路径", text: $path)
            }
            labelView("收款地址") {
                TextField("请输入收款地址", text: $address)
            }
            labelView("Nonce") {
                ValueView(value: $nonce, range: 0...1000, step: 1)
            }
            labelView("金额") {
                ValueView(value: $value)
            }
            labelView("手续费") {
                ValueView(value: $fee, range: 0...1.0)
            }
            labelView("限制") {
                ValueView(value: $limit, range: 0...100000, step: 1000)
            }
            Divider()
            HStack(alignment: .center) {
                Button("生成") {
                    #if os(macOS)
                    QR = Image(nsImage: generateQrcode())
                    #elseif os(iOS)
                    QR = Image(uiImage: generateQrcode())
                    #endif
                }
                .keyboardShortcut(.defaultAction)
            }
            QR.resizable().frame(width: 320, height: 320)
           
        }
        .padding()
    }

    func labelView(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        // also can use LabeledContent
        HStack {
            Text(label)
                .foregroundStyle(.blue)
                .frame(width: 80, alignment: .trailing)
            content()
        }
    }
}

// - MARK: - QRCode
extension TxQRView {
    func pathSeq() -> [UInt32] {
        path
            .split(separator: "/")
            .dropFirst()
            .map {
                guard $0.hasSuffix("'") else {
                    return UInt32($0) ?? 0
                }
                return UInt32($0.dropLast())! | 0x80000000
            }
    }
    
    func convertValue(_ value: Double, exp: Int = 0) -> Data {
        var v =  {
            let scale = exp > 0 ? 8 : 0 as Int16
            let handler = NSDecimalNumberHandler(roundingMode: .plain, scale: scale, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
            return NSDecimalNumber(decimal: Decimal(value)).rounding(accordingToBehavior: handler).decimalValue
        }()
        v *= pow(10, exp)
        let v256 = BigUInt("\(v)")
        print(v256!.serialize().hexString)
        return v256!.serialize()
    }
    
    #if os(macOS)
    func generateQrcode() -> NSImage {
        
        let ctx = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        var ethTx = Hw_Trezor_Messages_Ethereum_EthereumSignTx()
        ethTx.addressN = pathSeq()
        ethTx.to = address
        ethTx.value = convertValue(value, exp:  18)
        ethTx.nonce = convertValue(nonce)
        ethTx.gasPrice = convertValue(fee, exp: 18)
        ethTx.gasLimit = convertValue(limit)
        ethTx.chainID = 1

        // pb encode
        let mdata = try! ethTx.serializedData()
        
        let mtype = Hw_Trezor_Messages_MessageType.ethereumSignTx.rawValue
        let data = Data([UInt8(mtype >> 8), UInt8(mtype & 0xff)]) + mdata
        
        filter.setValue(data, forKey: "inputMessage")
        guard let outputImage = filter.outputImage else {
            return NSImage()
        }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let outputImageScaled = outputImage.transformed(by: transform)
        guard let cgImage = ctx.createCGImage(outputImageScaled, from: outputImageScaled.extent) else {
            return NSImage()
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: 320, height: 320))
    }
    #endif
    #if os(iOS)
    func generateQrcode() -> UIImage {
        
        let ctx = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        var ethTx = Hw_Trezor_Messages_Ethereum_EthereumSignTx()
        ethTx.addressN = pathSeq()
        ethTx.to = address
        ethTx.value = convertValue(value, exp:  18)
        ethTx.nonce = convertValue(nonce)
        ethTx.gasPrice = convertValue(fee, exp: 18)
        ethTx.gasLimit = convertValue(limit)
        ethTx.chainID = 1

        // pb encode
        let mdata = try! ethTx.serializedData()
        
        let mtype = Hw_Trezor_Messages_MessageType.ethereumSignTx.rawValue
        let data = Data([UInt8(mtype >> 8), UInt8(mtype & 0xff)]) + mdata
        
        filter.setValue(data, forKey: "inputMessage")
        guard let outputImage = filter.outputImage else {
            return UIImage()
        }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let outputImageScaled = outputImage.transformed(by: transform)
        guard let cgImage = ctx.createCGImage(outputImageScaled, from: outputImageScaled.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
    #endif
}

#Preview {
    TxQRView()
}

struct ToggleView<PrimeView: View, AlternateView: View>: View {
    let label: String
    let prime: PrimeView
    let alternate: AlternateView
    @State private var isPrime = true
    
    init(label: String, @ViewBuilder prime: () -> PrimeView, @ViewBuilder alternate: () -> AlternateView) {
        self.label = label
        self.prime = prime()
        self.alternate = alternate()
    }
    var body: some View {
        HStack {
            if isPrime {
                prime
            } else {
                alternate
            }
            
            Button(self.label) {
                isPrime.toggle()
            }
        }
    }
}

struct ValueView: View {
    @Binding private var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    init(value: Binding<Double>, range: ClosedRange<Double> = 0...100, step: Double? = nil) {
        self._value = value
        self.range = range
        self.step = step
    }
    var body: some View {

        ToggleView(label: "切换") {
            HStack {
                Button("-") {
                    var v = self.value
                    let step = (self.range.upperBound - self.range.lowerBound) / 100
                    v -= step
                    self.value = max(v, self.range.lowerBound)
                }
                Text(self.formater(self.value))
                    .frame(minWidth: 100)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Button("+") {
                    var v = self.value
                    let step = (self.range.upperBound - self.range.lowerBound) / 100
                    v += step
                    self.value = min(v, self.range.upperBound)
                }
                
                if let step = self.step{
                    Slider(value: $value, in: self.range, step: step)
                } else {
                    Slider(value: $value, in: self.range)
                }
            }
        } alternate: {
            TextField("请输入", text: Binding(
                get: { self.formater(self.value) },
                set: {
                    self.value = Double($0) ?? 0
                }
            ))
        }
    }
    
    func formater(_ value: Double) -> String {
        let formater = NumberFormatter()
        formater.numberStyle = .decimal
        formater.minimumFractionDigits = 0
        formater.maximumFractionDigits = 8
        if floor(value) == value {
            formater.maximumFractionDigits = 0
        }
        return formater.string(from: NSNumber(value: value)) ?? ""
    }
}


extension Data {
    var hexString: String {
        self.map{String.init(format: "%02x", $0)}.joined()
    }
    
    func chunks(size: Int) -> [Data] {
        stride(from: 0, to: count, by: size).map {
            let end = Swift.min($0 + size, count)
            return self[$0..<end]
        }
    }
}
