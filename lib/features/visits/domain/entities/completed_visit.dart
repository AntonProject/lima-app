/// Typed input for a completed visit write.
///
/// The presentation layer builds these values from its controls. API-shaped
/// maps are deliberately kept out of this layer and are produced by the data
/// mapper.
sealed class CompletedVisitPayload {
  const CompletedVisitPayload();
}

class LpuPresentationRecord {
  final int? drugId;
  final int statusId;
  final String drugName;
  final String manufacturer;
  final String status;

  const LpuPresentationRecord({
    required this.drugId,
    required this.statusId,
    required this.drugName,
    required this.manufacturer,
    required this.status,
  });
}

class LpuCompletedVisitPayload extends CompletedVisitPayload {
  final List<int> doctorIds;
  final String doctorName;
  final bool groupVisit;
  final String? groupVisitName;
  final List<LpuPresentationRecord> presentations;

  const LpuCompletedVisitPayload({
    required this.doctorIds,
    required this.doctorName,
    required this.groupVisit,
    this.groupVisitName,
    required this.presentations,
  });
}

class DiscussedDrugRecord {
  final int drugId;
  final List<int> documentIds;

  const DiscussedDrugRecord({required this.drugId, required this.documentIds});
}

class PharmaCircleCompletedVisitPayload extends CompletedVisitPayload {
  final String pharmacistName;
  final int participantsCount;
  final int materialsShownCount;
  final String visitFormatName;
  final List<DiscussedDrugRecord> discussedDrugs;

  const PharmaCircleCompletedVisitPayload({
    required this.pharmacistName,
    required this.participantsCount,
    required this.materialsShownCount,
    required this.visitFormatName,
    required this.discussedDrugs,
  });
}

class StockItemRecord {
  final int drugId;
  final String drugName;
  final String manufacturer;
  final String serialNumber;
  final String expiryDate;
  final int quantity;
  final int stock;

  const StockItemRecord({
    required this.drugId,
    required this.drugName,
    required this.manufacturer,
    required this.serialNumber,
    required this.expiryDate,
    required this.quantity,
    required this.stock,
  });
}

class StockDrugRecord {
  final int? incomeDetailingId;
  final int drugId;
  final int package;
  final double salePrice;
  final double salePriceWithoutNds;
  final String? serialNumber;
  final String? expiryDate;

  const StockDrugRecord({
    required this.incomeDetailingId,
    required this.drugId,
    required this.package,
    required this.salePrice,
    required this.salePriceWithoutNds,
    required this.serialNumber,
    required this.expiryDate,
  });
}

class StockCompletedVisitPayload extends CompletedVisitPayload {
  final List<StockItemRecord> stockItems;
  final List<StockDrugRecord> drugs;

  const StockCompletedVisitPayload({
    required this.stockItems,
    required this.drugs,
  });
}

class CompletedVisitDraft {
  final int organizationId;
  final String organizationName;
  final int? doctorId;
  final String? doctorName;
  final String localVisitType;
  final String notes;
  final String? medicalRepName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CompletedVisitPayload payload;

  const CompletedVisitDraft({
    required this.organizationId,
    required this.organizationName,
    required this.doctorId,
    required this.doctorName,
    required this.localVisitType,
    required this.notes,
    required this.medicalRepName,
    required this.createdAt,
    required this.updatedAt,
    required this.payload,
  });
}

class VisitWriteResult {
  final int localId;
  final int? remoteId;
  final bool remoteAccepted;
  final bool queuedForSync;
  final String? remoteError;

  const VisitWriteResult({
    required this.localId,
    required this.remoteId,
    required this.remoteAccepted,
    required this.queuedForSync,
    required this.remoteError,
  });
}
