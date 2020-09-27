//
//  APGPlayer.m
//  ios-audio
//
//  Created by mac on 2020/9/27.
//

#import "APGPlayer.h"

@implementation APGPlayer

static OSStatus renderCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
    NSLog(@"%u,%u",(unsigned int)inBusNumber,(unsigned int)inNumberFrames);
    return noErr;
}

-(id)initWithAudio:(NSString *)path{
    //1.1
    CFURLRef audioFileURL =(__bridge CFURLRef)[NSURL fileURLWithPath:path];
    
    //1.2
    OSStatus status=AudioFileOpenURL(                           // 2
                                     audioFileURL,              // 3
                                     kAudioFileReadPermission,  // 4
                                     0,                         // 5
                                     &mAudioFile                // 6
                                     );
    if (status != noErr) {//错误处理
        NSLog(@"*** Error *** PlayAudio - play:Path: could not open audio file. Path given was: %@", path);
    }
    CFRelease (audioFileURL);                                   // 7
    //1.3
    UInt32 dataFormatSize = sizeof (mDataFormat);           // 1
    AudioFileGetProperty (                                  // 2
        mAudioFile,                                         // 3
        kAudioFilePropertyDataFormat,                       // 4
        &dataFormatSize,                                    // 5
        &mDataFormat                                        // 6
    );
    [self printASBD:mDataFormat];
    
    /* Audio Unit Hosting */
    
    //1. 配置音频会话(AVAudioSession)
    double graphSampleRate=mDataFormat.mSampleRate;
    NSError *audioSessionError = nil;
    AVAudioSession *mySession = [AVAudioSession sharedInstance];                            // 1
    [mySession setPreferredSampleRate: graphSampleRate error: &audioSessionError];          // 2
    [mySession setCategory: AVAudioSessionCategoryPlayAndRecord error: &audioSessionError]; // 3
    [mySession setActive: YES error: &audioSessionError];                                   // 4
    self.graphSampleRate = mySession.sampleRate;                                            // 5
    
    //2. 指定所需的音频单元
    AudioComponentDescription ioUnitDesc;
    ioUnitDesc.componentType          = kAudioUnitType_Output;
    ioUnitDesc.componentSubType       = kAudioUnitSubType_RemoteIO;
    ioUnitDesc.componentManufacturer  = kAudioUnitManufacturer_Apple;
    ioUnitDesc.componentFlags         = 0;
    ioUnitDesc.componentFlagsMask     = 0;
    
    //3. 建立音频处理图
    //3.1.
    AUGraph processingGraph;
    NewAUGraph (&processingGraph);
    //3.2.
    AUNode ioNode;
    //3.3.
    AUGraphAddNode (processingGraph, &ioUnitDesc, &ioNode);
    //3.4.
    AUGraphOpen (processingGraph);
    //3.5.
//    AudioUnit ioUnit;
//    AUGraphNodeInfo (processingGraph, ioNode, NULL, &ioUnit);

    //4. 配置音频单元
    
    //5.
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc        = &renderCallback;
    callbackStruct.inputProcRefCon  = (__bridge void * _Nullable)(self);
     
    AUGraphSetNodeInputCallback (processingGraph,
                                 ioNode,
                                 0,                 // output element
                                 &callbackStruct);
    
    //8. 初始化并启动音频处理图
    status = AUGraphInitialize (processingGraph);
    // Check for error. On successful initialization, start the graph...
    AUGraphStart (processingGraph);
    
    return self;
}

- (void) printASBD: (AudioStreamBasicDescription) asbd {
 
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig (asbd.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
 
    NSLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"  Format ID:           %10s",    formatIDString);
    NSLog (@"  Format Flags:        %10X",    (unsigned int)asbd.mFormatFlags);
    NSLog (@"  Bytes per Packet:    %10u",    (unsigned int)asbd.mBytesPerPacket);
    NSLog (@"  Frames per Packet:   %10d",    (unsigned int)asbd.mFramesPerPacket);
    NSLog (@"  Bytes per Frame:     %10d",    (unsigned int)asbd.mBytesPerFrame);
    NSLog (@"  Channels per Frame:  %10d",    (unsigned int)asbd.mChannelsPerFrame);
    NSLog (@"  Bits per Channel:    %10d",    (unsigned int)asbd.mBitsPerChannel);
}

@end
