import 'package:genui/genui.dart';
import 'package:pawtfolio/catalog/bar_chart.dart';
import 'package:pawtfolio/catalog/budget_meter.dart';
import 'package:pawtfolio/catalog/donut_chart.dart';
import 'package:pawtfolio/catalog/expense_list.dart';
import 'package:pawtfolio/catalog/insight_alert.dart';
import 'package:pawtfolio/catalog/stat_card.dart';

/// Catalog id shared with the backend route's `default_catalog_id`.
///
/// The agent stamps `createSurface.catalogId` from it; [SurfaceController]
/// refuses to render a surface whose catalogId has no registered catalog — so
/// this MUST equal the backend `PAWTFOLIO_CATALOG_ID`.
const String kPawtfolioCatalogId = 'pawtfolio';

/// Description for the injected catalog context entry.
///
/// MUST be byte-identical to the backend's `A2UI_SCHEMA_CONTEXT_DESCRIPTION`
/// (ag_ui_adk): exact equality routes the schema into the sub-agent prompt.
const String kA2uiSchemaContextDescription =
    'A2UI Component Schema — available components for generating UI surfaces. '
    'Use these component names and properties when creating A2UI operations.';

/// Builds the Pawtfolio catalog: GenUI's basic components (layout/text/etc.)
/// minus media, plus the six custom finance components, stamped with
/// [kPawtfolioCatalogId]. `toCapabilitiesJson()` serializes all of these to the
/// agent automatically (the transport injects it into each run).
Catalog buildCatalog() => BasicCatalogItems.asCatalog()
    .copyWithout(
      itemsToRemove: [
        BasicCatalogItems.audioPlayer,
        BasicCatalogItems.video,
        BasicCatalogItems.image,
      ],
    )
    .copyWith(
      newItems: [
        statCard,
        donutChart,
        barChart,
        expenseList,
        budgetMeter,
        insightAlert,
      ],
      catalogId: kPawtfolioCatalogId,
    );
