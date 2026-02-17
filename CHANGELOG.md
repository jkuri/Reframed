# Changelog

## [v0.8.1](https://github.com/jkuri/Reframed/compare/v0.8.0...v0.8.1) (2026-02-17)

### Features

- **video:** add custom background image possible and make it work in preview and exported video as well ([2b42808](https://github.com/jkuri/Reframed/commit/2b42808fe992790bbd072c504332efafd070664c))
- **editor:** save editor window state like size and position and restore when reopened ([ddad8b2](https://github.com/jkuri/Reframed/commit/ddad8b2bb46f48d9fc477a24cf5bad7952e2b867))
- **camera:** improve the camera options in editor and fix some bugs around that topic ([cb22543](https://github.com/jkuri/Reframed/commit/cb22543961ef803609a9709780b1a073b95e5dd6))
- **camera:** implement webcam background manipulation ([ca93a7b](https://github.com/jkuri/Reframed/commit/ca93a7b6a881947d205fa1a2c168a2d724c586df))
- **camera:** add webcam mirror toggle and implement the feature ([448ba7a](https://github.com/jkuri/Reframed/commit/448ba7a476dd8fa35419397d90c2cbfb471cbee7))
- **editor:** make webcam toggle switch in editor and don't include its stream into transcoder when exporting in case its disabled ([3834da1](https://github.com/jkuri/Reframed/commit/3834da1e838b559de277dddb211968e3cae94a5b))
- **audio:** add microphone audio noise reduction func and re-generate waveform in real-time when changes are updated ([a8caa45](https://github.com/jkuri/Reframed/commit/a8caa4535ac158b1416381a28db3ed3e020db2c5))
- **audio:** add audio tab in editor settings and make muting and volume control possible ([80b98f4](https://github.com/jkuri/Reframed/commit/80b98f4e1b345a8e917a35ad7eaccdc6e181829b))
- **cursor:** implement new section for animate and add cursor movement speed based on spring (tension, friction, mass) - some hardcore styles ([6736c09](https://github.com/jkuri/Reframed/commit/6736c092e3bc5b628b1e6712bce5a5ae5c30c368))
- **editor:** add more gradients, make colors and gradients pickable and visible directly, fix the camera size, make camera aspect ratio configurable, add shadow option for both canvas and camera, make radius configurable in percent unit ([6cb0396](https://github.com/jkuri/Reframed/commit/6cb039693a07064d1c43fc8484129a5135bf69f8))

### Bug Fixes

- **timeline:** do not generate and render mic waveform twice initially ([d7f8381](https://github.com/jkuri/Reframed/commit/d7f8381a060c84fe9593861e5c679f90739209be))
- **video-compositor:** use .userInitiated QoS for both video and audio queues, matching the priority of the main thread that receives group.notify callback ([a5b2b7b](https://github.com/jkuri/Reframed/commit/a5b2b7bcfb85c19696b81138df9f02b7c01de53b))

### Performance

- **audio:** capture both system and mic audio at 320kbps and make option to reduce the quality in export ([e172bd4](https://github.com/jkuri/Reframed/commit/e172bd44f9c977c6d4dec9830f5ff083cf89ab63))

### Refactoring

- **editor:** make more reusable components for editor so we don't repeat ourselves, also some style improvements and other bug fixes are included in this one ([ff1db77](https://github.com/jkuri/Reframed/commit/ff1db777a5cc38f8310f6a074eceffa4be7c8caa))

### Chores

- **timeline:** make playhead animation look smoother ([9e7a54b](https://github.com/jkuri/Reframed/commit/9e7a54b4c263bb53173bcc843df26542f1b1a61f))

### Reverts

- **camera:** revert backgrounds for webcam as was unable to resolve halo effect ([7b81c12](https://github.com/jkuri/Reframed/commit/7b81c1253304281e736cb157f65f826eb7522a2e))

## [v0.8.0](https://github.com/jkuri/Reframed/compare/v0.7.0...v0.8.0) (2026-02-15)

### Features

- **shortcuts:** implement keyboard shortcuts for recording actions and make keystrokes customizable and configurable in settings ([6b2f7d8](https://github.com/jkuri/Reframed/commit/6b2f7d80780d6eeabc4b6d4f18ab52ca2f5b35c0))

### Styling

- **ui:** set dark mode panel backgrounds and light mode primary text to pure black. ([d16f48f](https://github.com/jkuri/Reframed/commit/d16f48f74607c998e349fa3b8652c6a9d4e0d09a))

### Chores

- specifically set recording border window sharingType to .none ([ea1244b](https://github.com/jkuri/Reframed/commit/ea1244bfe4d9aa8104efc700fc916d26b3c9f382))
- put window sharing type into constants and read it from there ([16a2b87](https://github.com/jkuri/Reframed/commit/16a2b87f7c7aaf3bb769fad28b2c000b01031479))

## [v0.7.0](https://github.com/jkuri/Reframed/compare/v0.6.0...v0.7.0) (2026-02-15)

### Features

- display capture mode, duration, webcam, and audio status for recent projects in the menu bar by updating project metadata and creation. ([64c6e94](https://github.com/jkuri/Reframed/commit/64c6e945e4b361abf44800987209446960b0df47))
- **cursor:** implement 20 different cursor styles ([521d8cf](https://github.com/jkuri/Reframed/commit/521d8cfd525aee7fa815fb4e751dc55025c7f915))
- **export:** make export better and more informational ([3e04415](https://github.com/jkuri/Reframed/commit/3e04415ea6de61899d0bde417b5cc4a59b7fa293))

### Bug Fixes

- camera display in full-screen mode ([2d2cfbe](https://github.com/jkuri/Reframed/commit/2d2cfbe1210a00e0a38b144a0048870bd3bb875f))
- export fixes and smaller video files ([aaaf0df](https://github.com/jkuri/Reframed/commit/aaaf0df78340892b0e44b5b607555e267f51a3b5))
- **export:** fix progress real-time and ETA info ([0127529](https://github.com/jkuri/Reframed/commit/0127529d1c1d9dad88393797a04b9a2eadb4fafe))

### Performance

- **export:** implement parallel multi-core exporting (optional) ([c9622bd](https://github.com/jkuri/Reframed/commit/c9622bd30ab4d1cadeb4effb99e0acfd78967528))
- reduce the exported video size ([5e78a58](https://github.com/jkuri/Reframed/commit/5e78a5846f29cf6a682195ab2038882ef34966a9))

### Refactoring

- **ui:** modify some styles on the UI to be consistent ([1667f71](https://github.com/jkuri/Reframed/commit/1667f71ec8ad12b0aa6ced37749fe1fc168dacce))
- **ui:** define constants for layout and use it ([2af7f04](https://github.com/jkuri/Reframed/commit/2af7f047247101796be953d60d29cff50750f048))
- **ui:** create reusable views where possible ([6a65a36](https://github.com/jkuri/Reframed/commit/6a65a369bf808272e4599e282a9cf5b5b5923e28))
- split views into smaller components ([601e5cc](https://github.com/jkuri/Reframed/commit/601e5ccb0d7b1b84ef3dfc4492af04c6b0ec8de0))

### Styling

- decrease SettingsView frame dimensions. ([924640b](https://github.com/jkuri/Reframed/commit/924640b8fccab6208c8dff86cf91f2e00aa710d3))
- **format:** add swift format command to the Makefile and run it ([921d848](https://github.com/jkuri/Reframed/commit/921d848c8cd1f521a02ebc256e25709d991574fd))

### Chores

- **rules:** add more rules to CLAUDE.md ([d064be8](https://github.com/jkuri/Reframed/commit/d064be8c6dab222b47f64d12694f63fcae478d19))

## [v0.6.0](https://github.com/jkuri/Reframed/compare/v0.5.0...v0.6.0) (2026-02-14)

### Features

- add recording info into general tab in properties panel ([acc7e46](https://github.com/jkuri/Reframed/commit/acc7e46eb3ff97c2a7ddc3a69b0c60564115c3a7))
- redesign the editor top bar ([8d4ebea](https://github.com/jkuri/Reframed/commit/8d4ebea98786088221fb7bdad65ffcd129a223f8))
- transport bar and preview mode in editor ([a64ced1](https://github.com/jkuri/Reframed/commit/a64ced16a3433083d20a19163e2ad858d0c51f8e))
- add camera full-screen option to timeline, some brutal stuff ([8addd02](https://github.com/jkuri/Reframed/commit/8addd027c1c5445513ec7d7d83f9c3dff27aa28b))
- add resize left/right cursor to video timeline track ([576788b](https://github.com/jkuri/Reframed/commit/576788b0e12e2db3f51535b215c85f477b715673))
- multi-region audio trimming ([86f8af0](https://github.com/jkuri/Reframed/commit/86f8af0c415a19e3d14b6deb4a5a3743a5b70438))
- change canvas size option in video editor ([0c2b52e](https://github.com/jkuri/Reframed/commit/0c2b52ec8af12e5316be4d6c14feebff90fd0a72))
- zoom handlers and custom regions ([bee5ff9](https://github.com/jkuri/Reframed/commit/bee5ff92633095904fa227c3653e3039d2c09d47))
- auto-zoom cursor pointer and follow ([2495930](https://github.com/jkuri/Reframed/commit/2495930e3b1d7bffe0a1529f4ac3bbf1dfe0b00d))
- add real-time audio level indicator for microphone and system audio while recording ([0d5b92f](https://github.com/jkuri/Reframed/commit/0d5b92f57c83b14bbe7741dc94abbe62da9282b5))
- extra menubar and improved video editor with trimming stuff at least some of it working ([cf328dd](https://github.com/jkuri/Reframed/commit/cf328dd8aa276a89001201da45ec08d005f088c5))

### Bug Fixes

- audio region dragging and resizing flicker or jumping fix ([780be10](https://github.com/jkuri/Reframed/commit/780be10a50a4a034a3bc4ec97b151c74a391e8c6))
- fix zoom positions on exported videos ([e2d896f](https://github.com/jkuri/Reframed/commit/e2d896fa95a5a4487841571c8de29f16ca38fc1e))
- zoom transitions in export are now smooth ([d19986d](https://github.com/jkuri/Reframed/commit/d19986d4fb0e68e7fe1d0809e5b422f8c585cd24))
- fix zoom presentation on the track and update it in real-time when slider values changes ([ce68006](https://github.com/jkuri/Reframed/commit/ce68006a124632932b109f410261d5e230ba0ea4))
- default macos rounded corners of the window respected when exporting the video ([18d551a](https://github.com/jkuri/Reframed/commit/18d551a50266d8138591e4106625a85edad9dd7b))
- mouse click renderer ([dc19e50](https://github.com/jkuri/Reframed/commit/dc19e509ed70683d9ed0ad8bc6e55e2093bd8824))

### Performance

- generate waveform faster and with progress status ([e9cfcc9](https://github.com/jkuri/Reframed/commit/e9cfcc90f630cfe657d46c37cf98f2db75e9c981))

### Refactoring

- rename PiP to Camera both files as labels, also some minor colors improvements on the editor ([3243edf](https://github.com/jkuri/Reframed/commit/3243edfbeee63170ba23b3573970b702fb318fc4))

### Styling

- **format:** add swift format command to the Makefile and run it ([c1085ff](https://github.com/jkuri/Reframed/commit/c1085ff2aacfd19f75fd2f3a111a72eba161c883))
- **format:** add swift format command to the Makefile and run it ([f3387aa](https://github.com/jkuri/Reframed/commit/f3387aa9e2b94c9f0e7bdde7af7d3552e25153fc))

### Documentation

- **readme:** update README.md with latest features ([b1b7ef2](https://github.com/jkuri/Reframed/commit/b1b7ef20159153378318a8275b67006670abdece))

### Chores

- styles and fixed on the timeline ([7f4a4ef](https://github.com/jkuri/Reframed/commit/7f4a4ef0669ab1aaddfbe432d0ae6d452d92aafd))
- make video timeline tracks with less opacity ([a5f1579](https://github.com/jkuri/Reframed/commit/a5f157963aba55bffecb433edce5f42d995d43b5))
- update system audio timeline track color and fix the styling for it ([8aad379](https://github.com/jkuri/Reframed/commit/8aad379b155af8cb3f989163af442163ac89a616))
- update CLAUDE.md ([3deb1b3](https://github.com/jkuri/Reframed/commit/3deb1b370df5e21b510599d7feddcf1b0f2e57d5))
- make timeline in editor look better ([7094568](https://github.com/jkuri/Reframed/commit/709456842f9f4f1d622b26a0d458886b4b2809d9))
- style webcam window preview ([1f2b8a5](https://github.com/jkuri/Reframed/commit/1f2b8a533ef018e06f28e73560a2ae3b2fd0eb61))
- minor changes on the editor layout ([ae8d413](https://github.com/jkuri/Reframed/commit/ae8d4138a085e8b0f91948e64d10a116aa02c2c9))
- improve timeline view colors ([074258c](https://github.com/jkuri/Reframed/commit/074258c4e597b99c5af5018b2c0b065c26aacf58))
- apply hovereffectscope to settings tab pillows ([898342c](https://github.com/jkuri/Reframed/commit/898342c715afe3c3f783cb9549fde0ae9ec439fd))
- improve menubar appearance ([33efe7f](https://github.com/jkuri/Reframed/commit/33efe7f57155ffcc9dfec6c63732ac8ea6451070))

## [v0.5.0](https://github.com/jkuri/Reframed/compare/v0.4.0...v0.5.0) (2026-02-12)

### Features

- **devices:** implement recording devices connected via USB like iPhone or iPad ([aec973b](https://github.com/jkuri/Reframed/commit/aec973bc51581074724daa17b0a398ebcfb55cbf))
- **toolbar:** make shared layout animation for items in toolbar ([a5c7471](https://github.com/jkuri/Reframed/commit/a5c74716adf98bf3559855d8831727e02cd04d63))

### Refactoring

- **rename:** rename project to Reframed ([1a3b5f7](https://github.com/jkuri/Reframed/commit/1a3b5f755013e4ca382137ab0daf238a3dd4eb23))

### Documentation

- **readme:** remove icon from the readme ([3ef0dbc](https://github.com/jkuri/Reframed/commit/3ef0dbc88b40b93ed8b47b9f92afb1e3ad957282))
- **readme:** update readme ([ffc6eae](https://github.com/jkuri/Reframed/commit/ffc6eaececb637e5054ac3defff9327355abf0a5))

## [v0.4.0](https://github.com/jkuri/Reframed/compare/v0.3.0...v0.4.0) (2026-02-12)

### Features

- add mouse click monitor settings where you can pick color, size and there's also a preview for this ([5eb7227](https://github.com/jkuri/Reframed/commit/5eb7227d3612df1db41560c76bc45b572fde3aaa))
- **capture:** implement mouse click monitor to capture mouse clicks in case this option is enabled ([c391e0e](https://github.com/jkuri/Reframed/commit/c391e0e05802ef212d9530281cb8808e95ca0b1b))
- **toolbar:** save last toolbar position into state ([dd08a9b](https://github.com/jkuri/Reframed/commit/dd08a9b549319ac8fca499335eff09bc3ada1a59))

### Bug Fixes

- **webcam:** stop the webcam preview when capture session is done ([e9e8336](https://github.com/jkuri/Reframed/commit/e9e83366b2eee0a7702627973d6f9359f9139a0c))
- **session:** make the restart button actually work ([da78a19](https://github.com/jkuri/Reframed/commit/da78a191706c28867bea02d96b538f2b3f7b1fa1))
- **area-mode:** fix race condition sometimes not displaying last state for area mode ([649a923](https://github.com/jkuri/Reframed/commit/649a923974c6dd8060475b9898d2bd0ef31214ad))
- **webcam:** fix webcam capture to respect resolution selected (if available) or fallbacks to best possible match available ([386c574](https://github.com/jkuri/Reframed/commit/386c5745bf4c26a16187f3c3ce1aa2e1a1b6e0d6))

### Refactoring

- **utils:** move reusable time formatting functions to utils ([8c0e7f3](https://github.com/jkuri/Reframed/commit/8c0e7f3d4f4584db9efb0d327bb03218c8bb1abd))
- **settings:** make whole settings as popover and not separate window ([82b3d44](https://github.com/jkuri/Reframed/commit/82b3d44e9ec5572f96e673211b686ac17c7a284c))

### Chores

- make mouse click preview larger ([81e649e](https://github.com/jkuri/Reframed/commit/81e649ea10d270fb667d277aad267feb442cba86))
- **settings:** redesign the settings popover with tabs ([32abe3a](https://github.com/jkuri/Reframed/commit/32abe3a2db7521a97cfecfb2fe23a2fc00eb885a))
- **colours:** multiple style and design improvements ([1b843c8](https://github.com/jkuri/Reframed/commit/1b843c835e6ba6ac1bc4a73b9c7e24d14ef0a766))

## [v0.3.0](https://github.com/jkuri/Reframed/compare/v0.2.0...v0.3.0) (2026-02-12)

### Features

- add sound effects for recording actions and refactor project folder handling ([f726b24](https://github.com/jkuri/Reframed/commit/f726b24dcb52ec314e27c56d9904a1be48ac8a9c))

### Bug Fixes

- multiple bug fixes and improvements, especially with device detection ([4b83886](https://github.com/jkuri/Reframed/commit/4b838868ce80e7bc4757769e197833fe2a3dfb43))

### Documentation

- **readme:** update readme ([533951a](https://github.com/jkuri/Reframed/commit/533951abf38da18a87d6665317a5c9eff7091c6b))
- **readme:** update README.md and add logo ([7c27130](https://github.com/jkuri/Reframed/commit/7c271307f49dcb7279d9a35e380022f112550e24))

### Chores

- update CLAUDE.md ([b482fac](https://github.com/jkuri/Reframed/commit/b482facdd12950c1c320890c9c22671bdaaae3f1))

### Build

- **Makefile:** update Makefile and simplify build and release commands ([98f58ca](https://github.com/jkuri/Reframed/commit/98f58cafc100edf23c7e0b858ac1516118868460))
- add Config.xcconfig where version is tracked ([6a6530a](https://github.com/jkuri/Reframed/commit/6a6530aee9138bbaab4f94ca61b9168699c8354f))
- **Makefile:** update Makefile ([5cf7526](https://github.com/jkuri/Reframed/commit/5cf7526990dc2626cf677713a90ce2ffc3e5fe48))

## [v0.2.0](https://github.com/jkuri/Reframed/compare/v0.1.0...v0.2.0) (2026-02-11)

### Features

- introduce the projects and .frm file format ([393e7a8](https://github.com/jkuri/Reframed/commit/393e7a8ed9b2c526c0323f1a7b2bd1efcd93c00d))
- enhanced video editor and export functionallity ([e6de3d4](https://github.com/jkuri/Reframed/commit/e6de3d44a4faddba9a4c548028121f893ec9188d))
- delay timer, resize webcam video in editor, bug fixes ([154ac3e](https://github.com/jkuri/Reframed/commit/154ac3e287783f20715d1452a4476e779b53ce30))
- webcam capture and simple video editor compositor ([c28a768](https://github.com/jkuri/Reframed/commit/c28a768bf093be11edafb9f367213b2932d1f934))

### Bug Fixes

- couple of PiP and video editor compositor style improvements and bug fixes ([ecfb403](https://github.com/jkuri/Reframed/commit/ecfb4039f56dccd8099ed4c8866626cf4122e3b2))
- **sync:** perfect sync for all streams recorded using shared clock ([5811e7b](https://github.com/jkuri/Reframed/commit/5811e7bca9beea5e61baaf2639ca1e1df5d57550))

### Styling

- **format:** format the source files ([065d1cb](https://github.com/jkuri/Reframed/commit/065d1cb731dd6709662a001496972b70dfc4eb08))
- format file using swift format ([b0a3c63](https://github.com/jkuri/Reframed/commit/b0a3c63ec0255a861bef738a204efbb3e6c51d9b))

## [v0.1.0](https://github.com/jkuri/Reframed/releases/tag/v0.1.0) (2026-02-10)

### Features

- light/dark mode ([5649703](https://github.com/jkuri/Reframed/commit/5649703a54805ead72c10f20ec2d0fb492df5ed8))
- mic working but not when system audio also enabled ([81af648](https://github.com/jkuri/Reframed/commit/81af6480411ac684a484088a121a5f1b367c7ef6))
- Add settings window, refactor window detection, and update UI for capture modes and app icon. ([148623c](https://github.com/jkuri/Reframed/commit/148623ce9eeb6abc1f808db3fc259b0bf8c76b79))
- Implement a dedicated permissions management system with a new UI for screen recording and accessibility access. ([50e9ffe](https://github.com/jkuri/Reframed/commit/50e9ffeed244296c6c5a6059dc258ccb8cd4b39a))
- Implement window capture mode with selection UI and updated recording session (not working selection ui okay, but commiting this) ([698eb4b](https://github.com/jkuri/Reframed/commit/698eb4befb8d660bc6828d3fa8c2649afd5ab274))
- Implement frame rate stabilization logic in screen capture and disable video frame reordering in video writer. ([50a065f](https://github.com/jkuri/Reframed/commit/50a065f9292af171b0e838fd766a6341f605f585))
- add H.264 main profile level to video compression settings. ([853349e](https://github.com/jkuri/Reframed/commit/853349ef3a5cd33455dfa90d9953ba762411efac))
- Switch video codec from HEVC to H.264 and refine video compression settings. ([c72c47d](https://github.com/jkuri/Reframed/commit/c72c47d94cf43a9c916b74a219ae04ccdb528392))
- Add text selection color and apply it to the NumberField tint. ([74738a1](https://github.com/jkuri/Reframed/commit/74738a13021c9394fad1d40402649f033555cf59))
- Introduce `NumberField` component and `FrameColors` enum, and refactor selection views to utilize them. ([0c68b34](https://github.com/jkuri/Reframed/commit/0c68b340149c4500154f88266bf7299dcbc2d71f))
- Introduce recording border UI and video transcoder, enhance screen capture performance, and raise recording FPS to 60. ([c0889f5](https://github.com/jkuri/Reframed/commit/c0889f5b373378df2f8263e8704732fd566b9d27))
- Add CLAUDE.md to provide project guidance for Claude AI. ([c09d341](https://github.com/jkuri/Reframed/commit/c09d341a18edd5d05df4a0d15e7b73aefdc0fff5))
- make recordings work ([10448b7](https://github.com/jkuri/Reframed/commit/10448b75a862bfd0a266e798526b07201fc68454))
- initial phase ([822e7c2](https://github.com/jkuri/Reframed/commit/822e7c2d22e12b2cf819c43f993ea7b9e876ad3f))

### Bug Fixes

- multiple bug fixes and improvements ([09cb2a4](https://github.com/jkuri/Reframed/commit/09cb2a47f40ccdb1a1c9df5f8dd63c4ee0d1d523))
- **ui:** multiple UI glitches are gone now ([ee7751e](https://github.com/jkuri/Reframed/commit/ee7751e01558452758557c2c0383bedc9fb1e3b2))
- make multiple audio stream works at the same time ([6d05528](https://github.com/jkuri/Reframed/commit/6d055285ddca5ef7df13b5c5979f5adc1b8619d2))
- fix captured video quality which is now perfect ([f07cbab](https://github.com/jkuri/Reframed/commit/f07cbabb39c035aa54e1f1ee334b767cb9bcd687))

### Refactoring

- brutal refactor - many stuff ([3cb7c6e](https://github.com/jkuri/Reframed/commit/3cb7c6e15a770d9eb633876df3b6ffed7acd48ca))
- Introduce `SessionState` to centralize application state and actions, replacing `CaptureCoordinator`, and add a new `SelectionControlsPanel` with updated resize handle sizing. ([d388f86](https://github.com/jkuri/Reframed/commit/d388f861220a30c8f6957840c7b3ed14f9fdb3c6))

### Documentation

- **readme:** add README.md ([4148e6f](https://github.com/jkuri/Reframed/commit/4148e6f80334112a84dbc72db0012d53c81ba0fe))

### Chores

- **docs:** update README.md with toolbar screenshot ([6588707](https://github.com/jkuri/Reframed/commit/6588707a16a8372286979c70c7f2c9d05a35eb85))
- add credits ([da108b8](https://github.com/jkuri/Reframed/commit/da108b85bf95aabd4e380e74ac0831c9b0dc9754))
- improve pause/resume sync video and audio, not perfect though ([e895dc2](https://github.com/jkuri/Reframed/commit/e895dc244ba69f005a4126e98cd592da4dfb1370))
- add .swift-format configuration and format all the files ([8ec8d3b](https://github.com/jkuri/Reframed/commit/8ec8d3b47e3cfd8dccbfce8c3c077dde4dc024e8))
- Apply Swift formatting and add build and DMG creation scripts. ([86c4d01](https://github.com/jkuri/Reframed/commit/86c4d0197170cc355489fb1f3a7dbef81db64c6a))
- ignore .agent/ directory ([79efe5b](https://github.com/jkuri/Reframed/commit/79efe5be7e5913b8a148387031070d6708ba449d))
- initial commit ([a9bb5c7](https://github.com/jkuri/Reframed/commit/a9bb5c7e2c77ccf49a6b4afae3379c32317438c3))

### Build

- Enable automatic code signing, update debug app launch command, and ignore .DS_Store files. ([353fc71](https://github.com/jkuri/Reframed/commit/353fc712ac379ddd0aedb8ffeb62e120e8f15d01))

