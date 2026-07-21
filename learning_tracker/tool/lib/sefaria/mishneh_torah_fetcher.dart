import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';

import 'sefaria_fetcher_base.dart';

/// Fetches Mishneh Torah (Rambam) content from Sefaria.
///
/// Parses each Hilchot sub-book via the Sefaria shape API into a 4-level
/// hierarchy: Sefer -> Hilchot -> Chapter -> Halakhah (~15,000 halakhot).
///
/// Ports the taxonomy of the authoritative Python curator
/// (`tool/curate_curricula/main.py::_strategy_mishneh_torah`): the 14 Sefarim
/// plus the Introduction in canonical [_sefarim] order, each Sefer's Hilchot
/// sub-books in title order, the three index-only titles excluded (Negative
/// Mitzvot / Positive Mitzvot / Overview of Mishneh Torah Contents — no usable
/// text), and the `Mishneh Torah, {Hilchot} {chapter}:{halakhah}` ref shape.
///
/// Hebrew display names follow the peer Dart fetchers' convention of Arabic
/// numerals (as [MishnaFetcher] emits `$heTitle N:M`) rather than the Python
/// asset's gematria — the Dart fetchers already diverge from the assets on
/// Hebrew formatting, and the asset's gematria additionally mis-encodes 16.
class MishnehTorahFetcher extends SefariaFetcherBase {
  MishnehTorahFetcher({required super.dio});

  @override
  String get curriculumId => CurriculumId.mishnehTorah.storageKey;

  @override
  Future<FetchResult> fetchAllContent() async {
    final items = <ContentItem>[];
    var sortOrder = 0;
    var leafCount = 0;

    for (final sefer in _sefarim) {
      // Sefer container (level1).
      items.add(
        ContentItem(
          curriculumId: curriculumId,
          level1: sefer.sefer,
          displayNameHe: sefer.heName,
          displayNameEn: sefer.sefer,
          sefariaRef: sefer.sefer,
          sortOrder: sortOrder++,
          isLeaf: false,
        ),
      );

      for (final book in sefer.books) {
        final shape = await fetchBookShape(book);
        final heTitle = shape['heTitle'] as String? ?? book;
        final chapters = shape['chapters'];

        // Hilchot container (level2).
        items.add(
          ContentItem(
            curriculumId: curriculumId,
            level1: sefer.sefer,
            level2: book,
            displayNameHe: heTitle,
            displayNameEn: book,
            sefariaRef: book,
            sortOrder: sortOrder++,
            isLeaf: false,
          ),
        );

        if (chapters is List) {
          // Standard Hilchot book: chapters[i] is the halakhah count of
          // chapter i + 1.
          for (var i = 0; i < chapters.length; i++) {
            final chapterNum = i + 1;
            final halakhahCount = (chapters[i] as num?)?.toInt() ?? 0;
            // Skip chapters Sefaria reports with no halakhot.
            if (halakhahCount == 0) continue;

            // Chapter container (level3).
            items.add(
              ContentItem(
                curriculumId: curriculumId,
                level1: sefer.sefer,
                level2: book,
                level3: chapterNum.toString(),
                displayNameHe: 'פרק $chapterNum',
                displayNameEn: 'Chapter $chapterNum',
                sefariaRef: '$book $chapterNum',
                sortOrder: sortOrder++,
                isLeaf: false,
              ),
            );

            // Halakhah leaves (level4).
            for (
              var halakhahNum = 1;
              halakhahNum <= halakhahCount;
              halakhahNum++
            ) {
              items.add(
                ContentItem(
                  curriculumId: curriculumId,
                  level1: sefer.sefer,
                  level2: book,
                  level3: chapterNum.toString(),
                  level4: halakhahNum.toString(),
                  displayNameHe: '$heTitle $chapterNum:$halakhahNum',
                  displayNameEn: '$book $chapterNum:$halakhahNum',
                  sefariaRef: '$book $chapterNum:$halakhahNum',
                  sortOrder: sortOrder++,
                  isLeaf: true,
                ),
              );
              leafCount++;
            }
          }
        } else {
          // Flat book (the Introduction, 'Transmission of the Oral Law'):
          // shape.chapters is a single int = the segment count. Each segment
          // is a leaf directly under the Hilchot container (3 levels deep),
          // mirroring _strategy_mishneh_torah's parse of a bare numeric tail.
          final segmentCount = (chapters as num?)?.toInt() ?? 0;
          for (var seg = 1; seg <= segmentCount; seg++) {
            items.add(
              ContentItem(
                curriculumId: curriculumId,
                level1: sefer.sefer,
                level2: book,
                level3: seg.toString(),
                displayNameHe: '$heTitle $seg',
                displayNameEn: '$book $seg',
                sefariaRef: '$book $seg',
                sortOrder: sortOrder++,
                isLeaf: true,
              ),
            );
            leafCount++;
          }
        }
      }
    }

    return FetchResult(
      items: items,
      hierarchyConfig: CurriculumHierarchyConfig(
        curriculumId: curriculumId,
        levelLabels: const ['Sefer', 'Hilchot', 'Chapter', 'Halakhah'],
        totalItems: leafCount,
      ),
    );
  }

  /// The 14 Sefarim of the Mishneh Torah plus the Introduction, in the
  /// canonical order of the Python curator's `sefer_order`. Each holds its
  /// Hilchot sub-books in title order. The three index-only titles (Negative
  /// Mitzvot / Positive Mitzvot / Overview of Mishneh Torah Contents) are
  /// omitted here exactly as `_strategy_mishneh_torah` excludes them.
  static const _sefarim = <_MishnehTorahSefer>[
    _MishnehTorahSefer('Introduction', 'הקדמה', [
      'Mishneh Torah, Transmission of the Oral Law',
    ]),
    _MishnehTorahSefer('Sefer Madda', 'ספר המדע', [
      'Mishneh Torah, Foreign Worship and Customs of the Nations',
      'Mishneh Torah, Foundations of the Torah',
      'Mishneh Torah, Human Dispositions',
      'Mishneh Torah, Repentance',
      'Mishneh Torah, Torah Study',
    ]),
    _MishnehTorahSefer('Sefer Ahavah', 'ספר אהבה', [
      'Mishneh Torah, Blessings',
      'Mishneh Torah, Circumcision',
      'Mishneh Torah, Fringes',
      'Mishneh Torah, Prayer and the Priestly Blessing',
      'Mishneh Torah, Reading the Shema',
      'Mishneh Torah, Tefillin, Mezuzah and the Torah Scroll',
      'Mishneh Torah, The Order of Prayer',
    ]),
    _MishnehTorahSefer('Sefer Zemanim', 'ספר זמנים', [
      'Mishneh Torah, Eruvin',
      'Mishneh Torah, Fasts',
      'Mishneh Torah, Leavened and Unleavened Bread',
      'Mishneh Torah, Rest on a Holiday',
      'Mishneh Torah, Rest on the Tenth of Tishrei',
      'Mishneh Torah, Sabbath',
      'Mishneh Torah, Sanctification of the New Month',
      'Mishneh Torah, Scroll of Esther and Hanukkah',
      'Mishneh Torah, Sheqel Dues',
      'Mishneh Torah, Shofar, Sukkah and Lulav',
    ]),
    _MishnehTorahSefer('Sefer Nashim', 'ספר נשים', [
      'Mishneh Torah, Divorce',
      'Mishneh Torah, Levirate Marriage and Release',
      'Mishneh Torah, Marriage',
      'Mishneh Torah, Virgin Maiden',
      'Mishneh Torah, Woman Suspected of Infidelity',
    ]),
    _MishnehTorahSefer('Sefer Kedushah', 'ספר קדושה', [
      'Mishneh Torah, Forbidden Foods',
      'Mishneh Torah, Forbidden Intercourse',
      'Mishneh Torah, Ritual Slaughter',
    ]),
    _MishnehTorahSefer('Sefer Haflaah', 'ספר הפלאה', [
      'Mishneh Torah, Appraisals and Devoted Property',
      'Mishneh Torah, Nazariteship',
      'Mishneh Torah, Oaths',
      'Mishneh Torah, Vows',
    ]),
    _MishnehTorahSefer('Sefer Zeraim', 'ספר זרעים', [
      'Mishneh Torah, Diverse Species',
      'Mishneh Torah, First Fruits and other Gifts to Priests Outside the Sanctuary',
      'Mishneh Torah, Gifts to the Poor',
      'Mishneh Torah, Heave Offerings',
      'Mishneh Torah, Sabbatical Year and the Jubilee',
      "Mishneh Torah, Second Tithes and Fourth Year's Fruit",
      'Mishneh Torah, Tithes',
    ]),
    _MishnehTorahSefer('Sefer Avodah', 'ספר עבודה', [
      'Mishneh Torah, Admission into the Sanctuary',
      'Mishneh Torah, Daily Offerings and Additional Offerings',
      'Mishneh Torah, Sacrifices Rendered Unfit',
      'Mishneh Torah, Sacrificial Procedure',
      'Mishneh Torah, Service on the Day of Atonement',
      'Mishneh Torah, The Chosen Temple',
      'Mishneh Torah, Things Forbidden on the Altar',
      'Mishneh Torah, Trespass',
      'Mishneh Torah, Vessels of the Sanctuary and Those Who Serve Therein',
    ]),
    _MishnehTorahSefer('Sefer Korbanot', 'ספר קרבנות', [
      'Mishneh Torah, Festival Offering',
      'Mishneh Torah, Firstlings',
      'Mishneh Torah, Offerings for Those with Incomplete Atonement',
      'Mishneh Torah, Offerings for Unintentional Transgressions',
      'Mishneh Torah, Paschal Offering',
      'Mishneh Torah, Substitution',
    ]),
    _MishnehTorahSefer('Sefer Taharah', 'ספר טהרה', [
      'Mishneh Torah, Defilement by Leprosy',
      'Mishneh Torah, Defilement by a Corpse',
      'Mishneh Torah, Defilement of Foods',
      'Mishneh Torah, Immersion Pools',
      'Mishneh Torah, Other Sources of Defilement',
      'Mishneh Torah, Red Heifer',
      'Mishneh Torah, Those Who Defile Bed or Seat',
      'Mishneh Torah, Vessels',
    ]),
    _MishnehTorahSefer('Sefer Nezikim', 'ספר נזיקין', [
      'Mishneh Torah, Damages to Property',
      'Mishneh Torah, Murderer and the Preservation of Life',
      'Mishneh Torah, One Who Injures a Person or Property',
      'Mishneh Torah, Robbery and Lost Property',
      'Mishneh Torah, Theft',
    ]),
    _MishnehTorahSefer('Sefer Kinyan', 'ספר קנין', [
      'Mishneh Torah, Agents and Partners',
      'Mishneh Torah, Neighbors',
      'Mishneh Torah, Ownerless Property and Gifts',
      'Mishneh Torah, Sales',
      'Mishneh Torah, Slaves',
    ]),
    _MishnehTorahSefer('Sefer Mishpatim', 'ספר משפטים', [
      'Mishneh Torah, Borrowing and Deposit',
      'Mishneh Torah, Creditor and Debtor',
      'Mishneh Torah, Hiring',
      'Mishneh Torah, Inheritances',
      'Mishneh Torah, Plaintiff and Defendant',
    ]),
    _MishnehTorahSefer('Sefer Shoftim', 'ספר שופטים', [
      'Mishneh Torah, Kings and Wars',
      'Mishneh Torah, Mourning',
      'Mishneh Torah, Rebels',
      'Mishneh Torah, Testimony',
      'Mishneh Torah, The Sanhedrin and the Penalties within Their Jurisdiction',
    ]),
  ];
}

class _MishnehTorahSefer {
  const _MishnehTorahSefer(this.sefer, this.heName, this.books);

  /// English Sefer name — also the `level1` value and the container ref.
  final String sefer;

  /// Hebrew Sefer name for the container's display.
  final String heName;

  /// Hilchot sub-book titles (full Sefaria `Mishneh Torah, X` form), sorted
  /// by title to match the Python curator's per-Sefer ordering.
  final List<String> books;
}
