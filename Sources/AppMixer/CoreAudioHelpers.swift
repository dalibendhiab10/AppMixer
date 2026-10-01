import CoreAudio
import AudioToolbox

enum CA {
    static func address(_ selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func get<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
                       scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, as: T.Type = T.self) -> T? {
        var addr = address(selector, scope: scope)
        var size = UInt32(MemoryLayout<T>.size)
        let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { ptr.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, ptr) == noErr else { return nil }
        return ptr.pointee
    }

    static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    static func objectList(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
        var addr = address(selector)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var list = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &list) == noErr else { return [] }
        return list
    }

    static var defaultOutputDevice: AudioObjectID? {
        CA.get(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice)
    }

    static func deviceUID(_ device: AudioObjectID) -> String? {
        string(device, kAudioDevicePropertyDeviceUID)
    }

    // MARK: Master volume of the default output device

    static func masterVolume() -> Float? {
        guard let dev = defaultOutputDevice else { return nil }
        return get(dev, kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                   scope: kAudioDevicePropertyScopeOutput, as: Float32.self)
    }

    static func setMasterVolume(_ value: Float) {
        guard let dev = defaultOutputDevice else { return }
        var addr = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        var v = Float32(max(0, min(1, value)))
        AudioObjectSetPropertyData(dev, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
    }

    // MARK: Output devices

    struct OutputDevice: Identifiable, Equatable {
        let id: AudioObjectID
        let name: String
    }

    static func outputDevices() -> [OutputDevice] {
        objectList(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDevices).compactMap { id in
            guard outputChannelCount(id) > 0,
                  let transport = get(id, kAudioDevicePropertyTransportType, as: UInt32.self),
                  transport != kAudioDeviceTransportTypeAggregate,
                  transport != kAudioDeviceTransportTypeVirtual,
                  get(id, kAudioDevicePropertyIsHidden, as: UInt32.self) != 1,
                  get(id, kAudioDevicePropertyDeviceCanBeDefaultDevice, scope: kAudioDevicePropertyScopeOutput, as: UInt32.self) != 0,
                  let name = string(id, kAudioObjectPropertyName) else { return nil }
            return OutputDevice(id: id, name: name)
        }
    }

    private static func outputChannelCount(_ id: AudioObjectID) -> Int {
        var addr = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeOutput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 16)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    /// Sets both the default output and the system-sounds output, like the native Sound menu.
    static func setDefaultOutputDevice(_ device: AudioObjectID) {
        for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultSystemOutputDevice] {
            var addr = address(selector)
            var d = device
            AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
                                       UInt32(MemoryLayout<AudioObjectID>.size), &d)
        }
    }
}
