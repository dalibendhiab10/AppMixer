import CoreAudio
import AudioToolbox
import Foundation
import os

/// Thread-shared gain. The audio thread reads `target`; a plain Float is fine for a single writer.
final class GainBox {
    var target: Float = 1
    var current: Float = 1
}

/// Captures the audio of one or more processes (muting their direct output) and plays it back
/// to the output device scaled by a gain.
@available(macOS 14.2, *)
final class AppTap {
    let processObjects: Set<AudioObjectID>
    let outputUID: String
    let gain = GainBox()

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "appmixer.io", qos: .userInteractive)

    init?(processObjects: Set<AudioObjectID>, outputUID: String, gain initial: Float) {
        self.processObjects = processObjects
        self.outputUID = outputUID
        gain.target = initial
        gain.current = initial

        let desc = CATapDescription(stereoMixdownOfProcesses: Array(processObjects))
        desc.uuid = UUID()
        desc.muteBehavior = .mutedWhenTapped
        desc.isPrivate = true

        let e1 = AudioHardwareCreateProcessTap(desc, &tapID)
        guard e1 == noErr else { NSLog("AppMixer: CreateProcessTap failed \(e1)"); return nil }

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "AppMixer Tap",
            kAudioAggregateDeviceUIDKey: "appmixer.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: desc.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        let e2 = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID)
        guard e2 == noErr else {
            NSLog("AppMixer: CreateAggregateDevice failed \(e2)"); stop(); return nil
        }

        let gain = self.gain
        let block: AudioDeviceIOBlock = { _, inData, _, outData, _ in
            let input = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inData))
            let output = UnsafeMutableAudioBufferListPointer(outData)
            let target = gain.target
            let start = gain.current
            for i in 0..<output.count {
                let out = output[i]
                guard let dst = out.mData?.assumingMemoryBound(to: Float.self) else { continue }
                memset(out.mData, 0, Int(out.mDataByteSize))
                guard i < input.count, let src = input[i].mData?.assumingMemoryBound(to: Float.self) else { continue }
                let bytes = min(Int(out.mDataByteSize), Int(input[i].mDataByteSize))
                let channels = max(Int(out.mNumberChannels), 1)
                let frames = bytes / MemoryLayout<Float>.size / channels
                guard frames > 0 else { continue }
                let step = (target - start) / Float(frames)
                var g = start
                for f in 0..<frames {
                    g += step
                    for c in 0..<channels { dst[f * channels + c] = src[f * channels + c] * g }
                }
            }
            gain.current = target
        }

        let e3 = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue, block)
        let e4 = e3 == noErr ? AudioDeviceStart(aggregateID, procID) : e3
        guard e4 == noErr else {
            NSLog("AppMixer: IOProc/Start failed \(e3) \(e4)"); stop(); return nil
        }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    deinit { stop() }
}
