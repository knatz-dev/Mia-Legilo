/// What the lab wires for an engine.
///
/// [FeatureSupport.wired] means the lab sends the setting. It is not a claim
/// that the setting survived a device run.
enum FeatureSupport { wired, unsupported }

class EngineProfile {
  const EngineProfile({
    required this.id,
    required this.name,
    required this.version,
    required this.repository,
    required this.license,
    required this.hostedInThisApp,
    required this.scrollArchitecture,
    required this.locatorNotes,
    required this.typography,
    required this.launchNote,
  });

  final String id;
  final String name;
  final String version;
  final String repository;
  final String license;
  final bool hostedInThisApp;
  final String scrollArchitecture;
  final String locatorNotes;
  final Map<String, FeatureSupport> typography;
  final String launchNote;

  bool supports(String feature) => typography[feature] == FeatureSupport.wired;
}

const epubRtlProfile = EngineProfile(
  id: 'epub_rtl',
  name: 'epub_rtl',
  version: '0.1.0',
  repository: 'https://github.com/AbdeldjalilChougui/epub_rtl',
  license: 'MIT',
  hostedInThisApp: true,
  scrollArchitecture:
      'One CustomScrollView of lazy sliver chapters. Parsed-chapter cache is 8. '
      'A 1px rule is drawn between chapters. Scroll mode does not use a PageView.',
  locatorNotes:
      'No EPUB CFI. Identity is spine index plus top-level block index. '
      'The within-block fraction is a layout hint, not the bookmark identity.',
  typography: {
    'fontSize': FeatureSupport.wired,
    'fontFamily': FeatureSupport.wired,
    'lineHeight': FeatureSupport.wired,
    'paragraphSpacing': FeatureSupport.wired,
    'margin': FeatureSupport.wired,
    'textAlignStart': FeatureSupport.wired,
    'textAlignJustify': FeatureSupport.wired,
    'textAlignCenter': FeatureSupport.unsupported,
    'textAlignEnd': FeatureSupport.unsupported,
    'theme': FeatureSupport.wired,
    'reducedMotion': FeatureSupport.wired,
  },
  launchNote: 'Pure Flutter. No WebView.',
);

const epubJsProfile = EngineProfile(
  id: 'flutter_epub_viewer',
  name: 'flutter_epub_viewer',
  version: '2.2.1',
  repository: 'https://github.com/fayis672/epub_viewer',
  license: 'BSD-3-Clause',
  hostedInThisApp: true,
  scrollArchitecture:
      'epub.js inside flutter_inappwebview. This lab sets flow=scrolled and '
      'manager=continuous, which is epub.js continuous mode. Whether chapter '
      'boundaries are actually seamless is not established until a device run. '
      'Upstream issue #27 reports scrolled chapter navigation overshooting.',
  locatorNotes:
      'startCfi is the semantic locator when present. progress is approximate '
      'and is not used as an identity. Spine index is not exposed by onRelocated.',
  typography: {
    'fontSize': FeatureSupport.wired,
    'fontFamily': FeatureSupport.wired,
    'lineHeight': FeatureSupport.wired,
    'paragraphSpacing': FeatureSupport.wired,
    'margin': FeatureSupport.wired,
    'textAlignStart': FeatureSupport.wired,
    'textAlignJustify': FeatureSupport.wired,
    'textAlignCenter': FeatureSupport.wired,
    'textAlignEnd': FeatureSupport.wired,
    'theme': FeatureSupport.wired,
    'reducedMotion': FeatureSupport.wired,
  },
  launchNote:
      'WebView. snap and Android snap animation are off. Scripted EPUB content is off.',
);

const foliateProfile = EngineProfile(
  id: 'foliate_js',
  name: 'foliate-js (Readest fork)',
  version: '090ccca6989a904f6df343538902bd8431c5a7a5',
  repository: 'https://github.com/readest/foliate-js',
  license: 'MIT',
  hostedInThisApp: true,
  scrollArchitecture:
      'Vendored foliate-paginator with flow=scrolled and without '
      'no-continuous-scroll. The paginator keeps adjacent section views in one '
      'scroll container. This is the mechanism Readest uses. It is not the '
      'Readest application, and it has not been measured on a device here.',
  locatorNotes:
      'relocate events carry an EPUB CFI. Section fraction from foliate is '
      'stored as progress and is approximate. The CFI is the identity.',
  typography: {
    'fontSize': FeatureSupport.wired,
    'fontFamily': FeatureSupport.wired,
    'lineHeight': FeatureSupport.wired,
    'paragraphSpacing': FeatureSupport.wired,
    'margin': FeatureSupport.wired,
    'textAlignStart': FeatureSupport.wired,
    'textAlignJustify': FeatureSupport.wired,
    'textAlignCenter': FeatureSupport.wired,
    'textAlignEnd': FeatureSupport.wired,
    'theme': FeatureSupport.wired,
    'reducedMotion': FeatureSupport.wired,
  },
  launchNote:
      'Original WebView host. Typography is injected CSS on the public load '
      'event. foliate-js has no documented typography method. Fixed-layout '
      'EPUBs are not vendored.',
);

const readiumProfile = EngineProfile(
  id: 'flutter_readium',
  name: 'flutter_readium',
  version: '0.9.1',
  repository: 'https://github.com/Notalib/flutter_readium',
  license: 'BSD-3-Clause',
  hostedInThisApp: false,
  scrollArchitecture:
      'Readium EPUB scroll mode replaces pagination with scrolling inside a '
      'resource. Crossing spine items is a separate navigator action. The '
      'isolated lab sets verticalScroll true so a device run can confirm that. '
      'A per-chapter vertical scroller does not satisfy R-001.',
  locatorNotes:
      'Readium Locator JSON is preserved whole in nativeLocator. progression '
      'inside a resource and totalProgression are approximate. There is no EPUB CFI.',
  typography: {
    'fontSize': FeatureSupport.wired,
    'fontFamily': FeatureSupport.wired,
    'lineHeight': FeatureSupport.wired,
    'paragraphSpacing': FeatureSupport.wired,
    'margin': FeatureSupport.wired,
    'textAlignStart': FeatureSupport.unsupported,
    'textAlignJustify': FeatureSupport.unsupported,
    'textAlignCenter': FeatureSupport.unsupported,
    'textAlignEnd': FeatureSupport.unsupported,
    'theme': FeatureSupport.wired,
    'reducedMotion': FeatureSupport.unsupported,
  },
  launchNote:
      'Isolated app at engines/flutter_readium_app because it requires '
      'compileSdk 37, AGP 9.1.1+, Gradle 9.3.1+ and FlutterFragmentActivity.',
);

const engineProfiles = <EngineProfile>[
  epubRtlProfile,
  epubJsProfile,
  foliateProfile,
  readiumProfile,
];

EngineProfile profileById(String id) =>
    engineProfiles.firstWhere((profile) => profile.id == id);
