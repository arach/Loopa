import CoreImage

protocol VideoFilterManagerProtocol {
    static func apply(filter: FilterType, to image: CIImage) -> CIImage
    // Add other methods as needed
}

class VideoFilterManager: VideoFilterManagerProtocol {
    static func apply(filter: FilterType, to image: CIImage) -> CIImage {
        switch filter {
        case .none:
            return image
        case .sepia:
            let f = CIFilter.sepiaTone()
            f.inputImage = image
            if f.inputKeys.contains("inputIntensity") {
                f.intensity = 1.0
            }
            return f.outputImage ?? image
        case .comic:
            let f = CIFilter.comicEffect()
            f.inputImage = image
            return f.outputImage ?? image
        case .posterize:
            let f = CIFilter.colorPosterize()
            f.inputImage = image
            if f.inputKeys.contains("inputLevels") {
                f.levels = 6
            }
            return f.outputImage ?? image
        case .noir:
            let f = CIFilter.photoEffectNoir()
            f.inputImage = image
            return f.outputImage ?? image
        case .mono:
            let f = CIFilter.photoEffectMono()
            f.inputImage = image
            return f.outputImage ?? image
        case .blur:
            let f = CIFilter.gaussianBlur()
            f.inputImage = image
            if f.inputKeys.contains("inputRadius") {
                f.radius = 5
            }
            return f.outputImage ?? image
        case .vignette:
            let f = CIFilter.vignette()
            f.inputImage = image
            if f.inputKeys.contains("inputIntensity") {
                f.intensity = 1.0
            }
            if f.inputKeys.contains("inputRadius") {
                f.radius = 2.0
            }
            return f.outputImage ?? image
        case .bloom:
            let f = CIFilter.bloom()
            f.inputImage = image
            if f.inputKeys.contains("inputIntensity") {
                f.intensity = 1.0
            }
            if f.inputKeys.contains("inputRadius") {
                f.radius = 10
            }
            return f.outputImage ?? image
        case .pixelate:
            let f = CIFilter.pixellate()
            f.inputImage = image
            if f.inputKeys.contains("inputScale") {
                f.scale = 10
            }
            return f.outputImage ?? image
        case .invert:
            let f = CIFilter.colorInvert()
            f.inputImage = image
            return f.outputImage ?? image
        }
    }
} 