# Changelog

## [v0.12.0](https://github.com/jkuri/Reframed/compare/v0.11.1...v0.12.0) (2026-03-01)

### Features

- **editor:** animate timeline track show/hide with smooth layout transitions ([587eda8](https://github.com/jkuri/Reframed/commit/587eda865422e4fa76abca09d33fdb4711cfe9bc))
- **effects:** add spotlight regions timeline track with per-region overrides and fade transitions ([30a9848](https://github.com/jkuri/Reframed/commit/30a98483ada3934ba84e09d667a5ad42821cb5ec))
- **effects:** add spotlight effect with compositor support and lenient codable decoders ([5cd894c](https://github.com/jkuri/Reframed/commit/5cd894cc712d2c3aee342baabce2e1299c364df5))
- **editor:** replace synthesized click sounds with 30 MP3 samples and add reusable Dropdown component ([0f759fa](https://github.com/jkuri/Reframed/commit/0f759fa925f1cf018249bfd96cada75d3d2e6983))

### Bug Fixes

- **editor:** hide muted audio and disabled camera tracks from timeline ([6bf1f37](https://github.com/jkuri/Reframed/commit/6bf1f377b4fd44c156c93ead399bdc62b4754a4a))
- **zoom:** merge overlapping auto-zoom regions before generating keyframes ([4071967](https://github.com/jkuri/Reframed/commit/407196720939184d151582fbfbd94dfcee8bab83))
- **editor:** hide screen shadow during transitions and disable cursor/zoom tabs without cursor data ([cf9cf56](https://github.com/jkuri/Reframed/commit/cf9cf56305c0b3b85269d7a83fa7b57769f7c261))

### Refactoring

- **editor:** replace History change descriptions with data-driven rules array ([b9e415e](https://github.com/jkuri/Reframed/commit/b9e415eac9eba59753f3ac3f74d0c9d7d320287b))

### Styling

- **editor:** update UI color palette, standardize corner radius, and refine borders across various components follow shadcn stuff ([92ceab4](https://github.com/jkuri/Reframed/commit/92ceab4651f59689f1a1a50f2bffe863fa0db8a4))

## [v0.11.1](https://github.com/jkuri/Reframed/compare/v0.11.0...v0.11.1) (2026-02-28)

### Features

- **menubar:** show pulsating processing icon during export and fix icon reset ([0553e1e](https://github.com/jkuri/Reframed/commit/0553e1e8c907808440189ec53dbebe72e81fa985))
- **menubar:** stop recording on menu bar icon click during capture ([9d7e3e8](https://github.com/jkuri/Reframed/commit/9d7e3e808515d1251abf7bb022845fd533bc767e))
- **menubar:** add custom programmatic menu bar icon with state variations ([d4cd813](https://github.com/jkuri/Reframed/commit/d4cd813158c7fc163b007b2aecebdb453e9e96ae))
- **captions:** add empty state when no speech is detected after transcription ([4c4a1e6](https://github.com/jkuri/Reframed/commit/4c4a1e6670b199dadeca0e1deb66049194ba935c))
- **captions:** replace model popover with segment picker and add sizes to descriptions ([ed3cc1e](https://github.com/jkuri/Reframed/commit/ed3cc1eba4d5001d93f0bdbcc5126667091b30a7))
- **captions:** auto-close model/language pickers and add language search ([43cc373](https://github.com/jkuri/Reframed/commit/43cc373ebcfb9a3a671b90269a133b4d13c63390))

### Bug Fixes

- **captions:** add cancel button for model download and fix download cancellation ([3fafde1](https://github.com/jkuri/Reframed/commit/3fafde14df20724d41fb116c860497b6e80b9e34))
- **captions:** filter out non-speech segments from transcription results ([7c29360](https://github.com/jkuri/Reframed/commit/7c2936055e6fde061b7cf976abae0e0a0c6a533a))
- **editor:** cancel in-flight tasks and guard waveform generation on project deletion ([a898c89](https://github.com/jkuri/Reframed/commit/a898c8923277c3d38c318d5beaaddb89c10777c8))
- **captions:** prefer denoised mic audio for caption transcription ([9c5744e](https://github.com/jkuri/Reframed/commit/9c5744e4f29d1f606fc60f8f13a2e2bf6a5c1a52))
- replace force unwraps with safe error handling and add resource cleanup deinits ([c21e693](https://github.com/jkuri/Reframed/commit/c21e693b4d17cec829de1b709e24df2c97d6234e))
- **editor:** cancel pending save task and reset project state when deleting a recording ([dd2ac26](https://github.com/jkuri/Reframed/commit/dd2ac265a953a539ce9a3fd00ff59520e8e1c03f))
- **capture:** focus captured window on recording start and improve toolbar window ordering. ([bced83b](https://github.com/jkuri/Reframed/commit/bced83b169b6455f557d338e10de1a048d0e8832))

### Refactoring

- **menubar:** make new menubar from scratch ([bd1b904](https://github.com/jkuri/Reframed/commit/bd1b9044c9d16acc589a1abfc27031e3101b654b))
- **style:** centralize and apply UI dimension constants for various components ([631aac2](https://github.com/jkuri/Reframed/commit/631aac20f20cc544dbaefa5d3363e0ffcca6be50))

### Styling

- **recording:** decrease window selection background opacity ([0f978f5](https://github.com/jkuri/Reframed/commit/0f978f555663f34e159049be4779cd5830f02b21))

### Chores

- **captions:** replace Whisper `small` model with `turbo` and update model size and description details ([9a5cc34](https://github.com/jkuri/Reframed/commit/9a5cc349b625675d2fa7a357e7675cc9d3c7f042))

## [v0.11.0](https://github.com/jkuri/Reframed/compare/v0.10.2...v0.11.0) (2026-02-28)

### Features

- **captions:** add caption history tracking and improve transcription ([b9c60d8](https://github.com/jkuri/Reframed/commit/b9c60d8f3d367024c0e726f059764e88fbafa542))
- **captions:** add speech-to-text captions using WhisperKit ([a7c6c8e](https://github.com/jkuri/Reframed/commit/a7c6c8e351010c8f3b8873b4391dc3b67ed055bd))
- **camera:** implement camera backgrounds - blur/color/gradient/image and make sure this also process in parallel when exporting ([d208dc9](https://github.com/jkuri/Reframed/commit/d208dc9c092ce9a8e790b824a8363b6a45084581))

### Bug Fixes

- **captions:** apply audio/video drift correction to caption timestamps ([505fac1](https://github.com/jkuri/Reframed/commit/505fac181ec89309e53234afe3137646f3fd8b2a))
- **captions:** fix segment grouping, display linger, and export sync ([b78dc2d](https://github.com/jkuri/Reframed/commit/b78dc2d4bb964a7bac3a03f8f3e20e468a18f39c))
- **sync:** add real-time audio/video drift correction during recording ([d44e7d4](https://github.com/jkuri/Reframed/commit/d44e7d48c24c0a565d9bc87b2934a068c896d16f))
- **export:** fix audio missing when video has cuts not starting at beginning ([ce8e703](https://github.com/jkuri/Reframed/commit/ce8e70325a0498b5d9449e42f1641a17a1c8ffd7))
- **camera:** fix fullscreen aspect ratio, fill mode, transitions, and cleanup ([a76543e](https://github.com/jkuri/Reframed/commit/a76543e2ca37432408e9cafc4314184a63194c09))
- **export:** preserve settings when preset switches to Custom ([6a63cad](https://github.com/jkuri/Reframed/commit/6a63cad40f1db942c8699d718dbb80836d0a1210))

### Performance

- **captions:** tune WhisperKit decoding options for faster transcription ([d5750f4](https://github.com/jkuri/Reframed/commit/d5750f4dcaef09811b398ce367182e9275255a93))

### Documentation

- **readme:** update with latest features and remove obvious entries ([26c1378](https://github.com/jkuri/Reframed/commit/26c13780fb69de9aed5420159a55776830eafc2b))
- **readme:** add gif presentation to the README.md ([7134173](https://github.com/jkuri/Reframed/commit/7134173ba986a12445de59c9de273232fdd041bd))

### Chores

- **docs:** add captions section to README ([21f2e91](https://github.com/jkuri/Reframed/commit/21f2e9134560f86dd255aa4096727ec1e6c8b9e9))
- **docs:** update README.md ([23bcc32](https://github.com/jkuri/Reframed/commit/23bcc32d67faac7932681d367aff9e9f6c953210))

## [v0.10.2](https://github.com/jkuri/Reframed/compare/v0.10.1...v0.10.2) (2026-02-26)

### Features

- **cursors:** implement SVG based cursors and make them from scratch with adjustable colors now ([2ccee06](https://github.com/jkuri/Reframed/commit/2ccee06df33d5d86614ef953999a12b8f669832c))
- **export:** add platform presets for quick export configuration ([ddee41c](https://github.com/jkuri/Reframed/commit/ddee41c8f330205c8f9b97e7358bf5411826ee00))

### Bug Fixes

- **export:** reset settings to defaults when switching to Custom preset ([247c25e](https://github.com/jkuri/Reframed/commit/247c25eb789f9179dc15fd9de444aa6ba049ba48))
- **editor:** improve cursor overlay smoothness in preview playback ([fb5ee2c](https://github.com/jkuri/Reframed/commit/fb5ee2caa4898c049503b76d85612228b7559de3))
- **shortcuts:** prevent global keyboard shortcuts from propagating to other apps during recording ([cf7a68f](https://github.com/jkuri/Reframed/commit/cf7a68f3e8cfb278e29c57d5e665534e9c664ab9))
- **permissions:** show permissions window on startup in case they are not granted already ([a9e5e51](https://github.com/jkuri/Reframed/commit/a9e5e516dcdc846e73696bdf61b12de1a7ea159b))

### Refactoring

- split large files into focused extensions and improve error logging ([3f3ad35](https://github.com/jkuri/Reframed/commit/3f3ad35afec2830a761058c9bc840914a3e5f53a))

### Styling

- **colors:** update colors for popovers and editor tracks ([a2f409e](https://github.com/jkuri/Reframed/commit/a2f409e00aadf6ea9c571a9df846c189ef90e800))

## [v0.10.1](https://github.com/jkuri/Reframed/compare/v0.10.0...v0.10.1) (2026-02-25)

### Bug Fixes

- **capture:** fix multiple display selection and capture for all three modes - display, window and area (closes #4) ([2b3ff7e](https://github.com/jkuri/Reframed/commit/2b3ff7e6a58a15cbe4902c944dfbf42e883c8d45))

### Chores

- **docs:** add llms.txt ([625b512](https://github.com/jkuri/Reframed/commit/625b5123df9836705ffef4c78a96a6ee923868a4))

## [v0.10.0](https://github.com/jkuri/Reframed/compare/v0.9.4...v0.10.0) (2026-02-24)

### Features

- **capture:** support multi-display selection for entire screen recording ([1647c9a](https://github.com/jkuri/Reframed/commit/1647c9ac599943e36edbe9d72928b94bca8560b6))
- **preview:** add progress ti preview mode and implement seek and drag to specific time section ([8bed9e2](https://github.com/jkuri/Reframed/commit/8bed9e29dcaf6906f5fffe91e77d894250f611f9))
- **video:** introduce the video regions and cut impl ([2b37010](https://github.com/jkuri/Reframed/commit/2b370101cbb4655ca18e44061758f0b98c0b7d04))

### Bug Fixes

- **ui:** use muted background for cursor style picker ([2827b99](https://github.com/jkuri/Reframed/commit/2827b99af6c59b49a466e5f236bdf529b215fbb9))
- **editor:** change default click highlight color to black ([40f05e8](https://github.com/jkuri/Reframed/commit/40f05e824b5a9dac7b0c1aca385214cb2d52bc8c))
- **editor:** snap smoothed cursor to click positions during spring simulation ([dca316a](https://github.com/jkuri/Reframed/commit/dca316af7d6ca5a097ce839e67513d763514df72))
- **editor:** don't show toolbar when editor window closes ([4e51114](https://github.com/jkuri/Reframed/commit/4e511140c7729abac14205bdb86f47fcf192f90b))
- **ui:** use primaryText color for success checkmarks ([02deb0e](https://github.com/jkuri/Reframed/commit/02deb0e5fd5641c5f1909ffa268cc984b2d9a826))
- **editor:** ensure history entries always have descriptive labels ([689de4f](https://github.com/jkuri/Reframed/commit/689de4f0a25b5177125ccfe221f131059665896e))
- **editor:** disable delete button while exporting ([947b712](https://github.com/jkuri/Reframed/commit/947b7121d646be7bf6d8505d002ade1c6bbcada6))
- **ui:** pin about tab footer to bottom of settings view ([9fd3b90](https://github.com/jkuri/Reframed/commit/9fd3b9013869dcd4f64deb1a0e388b95be2589b2))
- **ui:** update SliderRow label colors on appearance change ([274f45e](https://github.com/jkuri/Reframed/commit/274f45e9a2bf059e98945769ea34717bbbcb5955))
- **config:** correct default output folder name to ~/Movies/Reframed ([4472b3f](https://github.com/jkuri/Reframed/commit/4472b3f56a8e1b1229c9ae42bd41aa5dac359e15))
- **transition:** fix scale transition for screen in the editor preview ([8752870](https://github.com/jkuri/Reframed/commit/87528701f8eab5d7acb0013f3e5ecc17d5784359))
- **transition:** cursor in preview mode while in screen transiton now works properly ([400886c](https://github.com/jkuri/Reframed/commit/400886c4bfdb8e780d9c05666ebeb1db73f37f4c))
- **transition:** fix transitions in editor preview mode ([b88526e](https://github.com/jkuri/Reframed/commit/b88526e54235cdb8231fcbe3f02132c597be7d9e))
- **export:** fix parallel export crashing sometimes when cancel ([04492ce](https://github.com/jkuri/Reframed/commit/04492ceb82b5060cbd0d7d14f34b48310a5fbd13))
- **zoom:** use ZTP formula for zoom in and out transition ([51f3134](https://github.com/jkuri/Reframed/commit/51f31342218188aee967004b3ef8d25cee6ff877))

### Refactoring

- **editor:** move cursor movement section from Animate tab to Cursor tab ([e3e2b7d](https://github.com/jkuri/Reframed/commit/e3e2b7d2f483589e382cadb4ba695b6a5e18b6b2))
- remove unused files and function implementations, rename some methods and other stuff ([3e89f77](https://github.com/jkuri/Reframed/commit/3e89f770df80cdfe0f9d1f7d042a3be2ad4a844b))

### Styling

- **capture:** fix window mode capture to follow same new styles ([9da8c0f](https://github.com/jkuri/Reframed/commit/9da8c0f9972369b30752675021c66e25b773effa))

### Documentation

- add root-cause fix guideline to code style section ([f18ae7e](https://github.com/jkuri/Reframed/commit/f18ae7ef02faf794599a0f10bd5788471dbf02d5))

### Chores

- create dmg signing script ([2d818bd](https://github.com/jkuri/Reframed/commit/2d818bdd170242049cef987edbdf2abe3327a2ba))

## [v0.9.4](https://github.com/jkuri/Reframed/compare/v0.9.3...v0.9.4) (2026-02-21)

### Features

- **recording:** add option to hide webcam preview while recording ([1daaa78](https://github.com/jkuri/Reframed/commit/1daaa7806f986fb2d1444e3c7c51c217e00158cc))

### Bug Fixes

- **tranisiton:** make slide camera animation go off screen no matter what height is configured ([bba8bda](https://github.com/jkuri/Reframed/commit/bba8bda593b62d00aaaf5a15d1ef236a19fa8def))
- **cursor:** make webcam PiP have higher z-index than cursor ([fd8009a](https://github.com/jkuri/Reframed/commit/fd8009aa393a32f535df866a1a53e774474b9efa))

### Performance

- **transitions:** show background capture while in full-screen webcam transition mode ([1ad8cd9](https://github.com/jkuri/Reframed/commit/1ad8cd9332da1ee30af6669561fa45d6712b5c5f))

### Styling

- **app:** restyle the whole app using shadcn monochrome colours ([be3e89b](https://github.com/jkuri/Reframed/commit/be3e89be1b1228513efaaf74bf3eefe3f24b8f7e))

### Documentation

- **claude:** update CLAUDE.md specs ([4bad85f](https://github.com/jkuri/Reframed/commit/4bad85f195ef3755bf90f5727d0b7cdcfb40ce64))

## [v0.9.3](https://github.com/jkuri/Reframed/compare/v0.9.2...v0.9.3) (2026-02-20)

### Features

- **animations:** make camera PiP animations like fade, slide in, scale work in both preview and export ([f286360](https://github.com/jkuri/Reframed/commit/f28636000aeb2c4df6dd9e1457c018097d5f8db8))
- **camera:** add option for custom style and position regions on webcam webcam track ([ff8069e](https://github.com/jkuri/Reframed/commit/ff8069e93cbfb58d8375917ee0d371810780ec49))
- **camera:** enhance camera regions with option to hide camera on specific sections on the timeline ([54e3166](https://github.com/jkuri/Reframed/commit/54e31660efb4a615b3ecd5b5b10c31abe9718727))
- **settings:** add about section in settings popover and check for updates feature ([a751572](https://github.com/jkuri/Reframed/commit/a751572f19d47365ba8546f7fd6200552fd9efba))
- **editor:** add more info about the project in the panel ([d621371](https://github.com/jkuri/Reframed/commit/d621371b579dfc5d232378dc8d4bb0cf84430627))
- **recording:** make option to enable/disable outer area as dimmed while recording ([71d6ca2](https://github.com/jkuri/Reframed/commit/71d6ca2b4f54664896efc1f23bdd73391ef18ed4))
- **video:** switch standard quality video encoding to H.265 (HEVC) 10-bit and update related UI labels and descriptions ([81aeea5](https://github.com/jkuri/Reframed/commit/81aeea53701c2b62aa5db7b11b1baad6ec7776fb))
- **capture:** adjusted video export bitrates and keyframe intervals, removed specific compression properties, and set global high interpolation quality for camera video rendering. ([307febf](https://github.com/jkuri/Reframed/commit/307febf07b8d7a7c780017db4e01c1a8a350ba92))
- **capture:** enhance capturing screen with options like superscale, codec selection and some other stuff ([2a945c4](https://github.com/jkuri/Reframed/commit/2a945c49ac73852037080b47edcf8fcc6a2c7a6c))

### Bug Fixes

- **preview:** fix camera bugs around PiP camera bounds and rendering ([7ad4c84](https://github.com/jkuri/Reframed/commit/7ad4c846173302f83af30824de39e52055831f4a))
- **compositor:** make sure manual export also keep the fps as requested ([33f861c](https://github.com/jkuri/Reframed/commit/33f861c66a3f1ed431ef6e29f4b4f805706d8445))
- **metadata:** write correct metadata about cursor in case of window recording and dragged to another position ([171f5ff](https://github.com/jkuri/Reframed/commit/171f5ffc4446187a32226231fdcb7ffbba30c68c))
- **config:** merge existing config values in case of a new property is defined, make it backward compatible ([6003119](https://github.com/jkuri/Reframed/commit/6003119bd0975552288d52371557f95faa8ebf8b))
- **config:** save state of audio streams ([b76eff2](https://github.com/jkuri/Reframed/commit/b76eff2158ad1cb2732b2dff0e5afa9f4e4e790f))
- **recording:** update dimmed area and border in case recording specific window and its dragged to new position ([3ac2569](https://github.com/jkuri/Reframed/commit/3ac25690ea84335ec895ea9199d0f707b2623de9))

### Performance

- **camera:** lower down the bitrate multiplier in case of webcam ([7dbc64d](https://github.com/jkuri/Reframed/commit/7dbc64d5856bb995e9139c2ad70c7d583260fed9))
- **video:** match bitreate of captured and exported video ([0692f2d](https://github.com/jkuri/Reframed/commit/0692f2d357970ac27eca1bbd69a400c1c8551b4a))
- **video:** improve the quality of the captured and exported video ([74d7f84](https://github.com/jkuri/Reframed/commit/74d7f8488901e78c92fa0057613130596e676419))

### Refactoring

- **colors:** make all colors used in timeline tracks in hex format for easier changes ([bc4d259](https://github.com/jkuri/Reframed/commit/bc4d259055533fed15d3eaed854618da3a9f71f1))
- **compositor:** break video compositor into more source files ([aaa7052](https://github.com/jkuri/Reframed/commit/aaa70523754a329c55ba627a8bd46f358a61b06a))
- **settings:** refactor EditorView's tap gesture handling to reliably resign the first responder and update the UpdateChecker to use nonisolated functions for improved concurrency. ([ef130b8](https://github.com/jkuri/Reframed/commit/ef130b80e684f700baaf7ded70923f7d49da9cc5))
- **ui:** make reusable inline editable text component and use it for renaming the project ([e93c668](https://github.com/jkuri/Reframed/commit/e93c668af096d258ea1b67ddde1480928f4b041e))
- **ux:** improve the behavour of the device recording and show the preview before it starts recording ([dc18a26](https://github.com/jkuri/Reframed/commit/dc18a268f0451e04ef02f796e1ac56bd44c273d1))
- **ux:** improve the user xp before start recordin, in countdown mode, overlay removed ([0639424](https://github.com/jkuri/Reframed/commit/063942436420fd8aada1718c9ba46561ce4e432a))

### Styling

- **topbar:** minor export button padding fix ([f0b7bf7](https://github.com/jkuri/Reframed/commit/f0b7bf756c23ed5a0c8f0990cbb00b0e9c68c14a))
- **colours:** update the mic and system audio track colors to look better on both light and dark mode ([f4213e3](https://github.com/jkuri/Reframed/commit/f4213e3bc0a626b99b5eb4e2c1d3d1a63d34d3b2))
- **zoom:** update manual zoom region edit popover to consistently follow the colors across the app ([10b2a78](https://github.com/jkuri/Reframed/commit/10b2a78555c4194f62b1bfeb769e99fc585568a9))
- **editor:** improve the camera region edit popover dialog ([18f7b01](https://github.com/jkuri/Reframed/commit/18f7b01ebb4ff1ea71581fdaf5b3e1f62360a79f))
- **editor:** modify the colours and border radius on editor elements ([b3959a1](https://github.com/jkuri/Reframed/commit/b3959a187dcbd24572fe1ea56786921311fdbad8))
- **menubar:** improve the style ef menubar items ([2a79a25](https://github.com/jkuri/Reframed/commit/2a79a254820cff4af1dc4d644b20e43d4138703b))
- **properties-panel:** improve readability and display project size in general info ([64372a0](https://github.com/jkuri/Reframed/commit/64372a0cdafe6288da354fe0afed3dd867661941))

### Documentation

- **readme:** add new icon to the readme section ([4532b67](https://github.com/jkuri/Reframed/commit/4532b67b6976b3fea6508234957c4c0eb27caf00))

### Chores

- **settings:** update text for supersample description ([a11b5e8](https://github.com/jkuri/Reframed/commit/a11b5e8782f306ec29901e4617df49a35e60f31e))

## [v0.9.2](https://github.com/jkuri/Reframed/compare/v0.9.1...v0.9.2) (2026-02-19)

### Features

- **capture:** adjusted video export bitrates and keyframe intervals, removed specific compression properties, and set global high interpolation quality for camera video rendering. ([e4140ef](https://github.com/jkuri/Reframed/commit/e4140ef2c016ee8d86dcd94225fb5667322ed984))
- **capture:** enhance capturing screen with options like superscale, codec selection and some other stuff ([f736879](https://github.com/jkuri/Reframed/commit/f736879c4b2fb6fc6fc80ba28a7e70748598f310))

### Chores

- **icon:** new AppIcon ([15875a2](https://github.com/jkuri/Reframed/commit/15875a28e22e0f23a0ceaca4730f1b9495da08f3))

## [v0.9.1](https://github.com/jkuri/Reframed/compare/v0.9.0...v0.9.1) (2026-02-18)

### Features

- **export:** add ProRes 4444 and ProRes 422 codec options ([efe06a3](https://github.com/jkuri/Reframed/commit/efe06a36d95d66451749f3245b786e185f923aab))
- **export:** add gif export option available using gifski lib, progressbar and eta also implemented ([4ce7a62](https://github.com/jkuri/Reframed/commit/4ce7a62e183b8ec54f3402ce3262b054e73c0429))
- **export:** make export dialog when done restyles and with copy to clipboard action ([22abde3](https://github.com/jkuri/Reframed/commit/22abde38b462c63c8684f5013fc2153fef809294))
- **camera:** make full-screen mode options like aspect ratio and fill mode for webcam ([eb38282](https://github.com/jkuri/Reframed/commit/eb38282ac3c8f46d6fa475b155dbf931d41faa78))

### Refactoring

- **ui:** make components and view reusable where possible and don't repeat the code ([5cbd82b](https://github.com/jkuri/Reframed/commit/5cbd82b439d124dcb90808916dd2c0063de99679))

### Styling

- **colors:** make editor colors apply on change and make history popover match styles of other popovers in the app ([dd8b3d5](https://github.com/jkuri/Reframed/commit/dd8b3d5ec665a3fbb95885e61a36a777b51b77a9))
- **appearance:** make sure all colors are updated when switch appearance (light/dark) mode ([e654bbb](https://github.com/jkuri/Reframed/commit/e654bbb487b30feddc57400c68cb55df7b924f3a))

### Documentation

- **readme:** add Homebrew install command to download section ([d31a031](https://github.com/jkuri/Reframed/commit/d31a0314cf481cea6c362ed573669e6fe7f10feb))
- **readme:** add editor screencast gif ([20c1f46](https://github.com/jkuri/Reframed/commit/20c1f4603e9a21a234cc4451af5ed3aca0652fa4))
- **readme:** add cursor metadata, zoom & pan, and GIF export sections ([9302678](https://github.com/jkuri/Reframed/commit/9302678173ad40da98d60aae11bb3ca053726531))
- **readme:** add ProRes 422 and ProRes 4444 to export codec list ([93bc8e8](https://github.com/jkuri/Reframed/commit/93bc8e861bdc571acfb646a646ec793b7936baa8))
- **claude:** update CLAUDE.md specs ([d6cf4d9](https://github.com/jkuri/Reframed/commit/d6cf4d9187d5b6fed2120bc5b28ec48b270e88ca))

## [v0.9.0](https://github.com/jkuri/Reframed/compare/v0.8.2...v0.9.0) (2026-02-18)

### Features

- **timeline:** improve the timeline zoom and scrollbar ([5689f45](https://github.com/jkuri/Reframed/commit/5689f45fbf47ecc1f66e3f69c6152d95d6211095))
- **audio:** cache denoised mic audio stream so it doesn't regenerates everytime you open the project, also use the cached stream when exporting ([97d1d22](https://github.com/jkuri/Reframed/commit/97d1d22012892090065532b4c70b2f7614749ca4))
- **timeline:** add zoom to timeline ([76efdb7](https://github.com/jkuri/Reframed/commit/76efdb7e3bc38d2d48897ce3565a18f982b96553))
- **history:** make popover to rollback to specific history snaphot ([b42cec8](https://github.com/jkuri/Reframed/commit/b42cec8d3ca6c75fb988ab64ce2aff0c5e75d966))
- **editor:** save history of actions done on editor, undo/redo implemented ([70f5ee3](https://github.com/jkuri/Reframed/commit/70f5ee3412ceecafaa1b89a17f42a752f270b89a))

### Bug Fixes

- **timeline:** improve handlers for resize/drag on all tracks ([ed3086a](https://github.com/jkuri/Reframed/commit/ed3086a8a784e5acd23243c646702dd835640179))
- **audio:** fix denoising progress tracker to yield current right current status ([73f37ed](https://github.com/jkuri/Reframed/commit/73f37ed86d4ab33cb12c7023744959f442aa6d49))

### Chores

- **claude:** add swiftui and swift concurrency skills for claude code ([d6951a0](https://github.com/jkuri/Reframed/commit/d6951a0aeaf32aa7fb48f57e363cf66f1f7e6eeb))
- **export:** change the order of audio bitrate options ([3faca95](https://github.com/jkuri/Reframed/commit/3faca95d5f92e4b5dd91588bbc70365e28e6b41d))

### Build

- **Makefile:** make dmg now creates universal  release for both Intel x86 and Apple Silicon ([40d6d6d](https://github.com/jkuri/Reframed/commit/40d6d6d9c7c6e61821ca1815be1c27e0c93160ba))

## [v0.8.2](https://github.com/jkuri/Reframed/compare/v0.8.1...v0.8.2) (2026-02-17)

### Features

- **audio:** add noise reducer for microphone audio stream using RNNoise ([b060695](https://github.com/jkuri/Reframed/commit/b060695eb613b3e06ba712c0c4ad4c3e287dc426))

### Bug Fixes

- **audio:** show loading status while regenerating mic audio waveform ([e33a834](https://github.com/jkuri/Reframed/commit/e33a834eafbd043eba82799a8cfb1bc7ae857783))
- **audio:** filter out CADefaultDeviceAggregate from mic selection in both options and settings, make sure they are set to nil in teardown procedure ([a60fce6](https://github.com/jkuri/Reframed/commit/a60fce6eb3f677ff93feeaace27f387c9d586dfe))

### Refactoring

- **audio:** remove AudioNoiseReducer file, was just a trivial passthrough to RNNoiseProcessor ([178daf7](https://github.com/jkuri/Reframed/commit/178daf73ec5aac19847fe712480dba1a0dda0522))

### Documentation

- **readme:** update README.md with mic noise reducer description ([4ef3fb1](https://github.com/jkuri/Reframed/commit/4ef3fb1b45df21d14d3cdd8c461e6b038fd02e83))

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

