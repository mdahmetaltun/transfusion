// ignore_for_file: constant_identifier_names
enum BloodProductType { ES, TDP, TSP, KRIYO }

enum BloodGroup { A, B, AB, O, unknown }

enum RhFactor { positive, negative, unknown }

enum ProductStatus { registered, received, administered, returned, wasted }

class BloodProductUnit {
  final String id;
  final String caseId;
  final BloodProductType productType;
  final String barcode;
  final String lotNumber;
  final DateTime expiryDate;
  final BloodGroup bloodGroup;
  final RhFactor rhFactor;
  final String dispatchedBy;
  final DateTime registeredAt;
  DateTime? receivedAt;
  DateTime? administeredAt;
  ProductStatus status;
  String? notes;

  BloodProductUnit({
    required this.id,
    required this.caseId,
    required this.productType,
    required this.barcode,
    required this.lotNumber,
    required this.expiryDate,
    required this.bloodGroup,
    required this.rhFactor,
    required this.dispatchedBy,
    required this.registeredAt,
    this.receivedAt,
    this.administeredAt,
    this.status = ProductStatus.registered,
    this.notes,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);

  bool get isExpiringSoon {
    final now = DateTime.now();
    final diff = expiryDate.difference(now);
    return diff.inHours <= 24 && diff.inSeconds > 0;
  }

  String get productTypeLabel {
    switch (productType) {
      case BloodProductType.ES:
        return 'ES (Eritrosit Süspansiyonu)';
      case BloodProductType.TDP:
        return 'TDP (Taze Donmuş Plazma)';
      case BloodProductType.TSP:
        return 'TSP (Trombosit Süspansiyonu)';
      case BloodProductType.KRIYO:
        return 'KRİYOPRESİPİTAT';
    }
  }

  String get productTypeShortLabel {
    switch (productType) {
      case BloodProductType.ES:
        return 'ES';
      case BloodProductType.TDP:
        return 'TDP';
      case BloodProductType.TSP:
        return 'TSP';
      case BloodProductType.KRIYO:
        return 'KRIYO';
    }
  }

  String get bloodGroupLabel {
    switch (bloodGroup) {
      case BloodGroup.A:
        return 'A';
      case BloodGroup.B:
        return 'B';
      case BloodGroup.AB:
        return 'AB';
      case BloodGroup.O:
        return 'O';
      case BloodGroup.unknown:
        return 'Bilinmiyor';
    }
  }

  String get rhFactorLabel {
    switch (rhFactor) {
      case RhFactor.positive:
        return 'Rh+';
      case RhFactor.negative:
        return 'Rh-';
      case RhFactor.unknown:
        return '';
    }
  }

  String get statusLabel {
    switch (status) {
      case ProductStatus.registered:
        return 'KAYITLI';
      case ProductStatus.received:
        return 'ALINDI';
      case ProductStatus.administered:
        return 'UYGULANDP';
      case ProductStatus.returned:
        return 'İADE EDİLDİ';
      case ProductStatus.wasted:
        return 'İMHA EDİLDİ';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'caseId': caseId,
      'productType': productType.name,
      'barcode': barcode,
      'lotNumber': lotNumber,
      'expiryDate': expiryDate.toIso8601String(),
      'bloodGroup': bloodGroup.name,
      'rhFactor': rhFactor.name,
      'dispatchedBy': dispatchedBy,
      'registeredAt': registeredAt.toIso8601String(),
      'receivedAt': receivedAt?.toIso8601String(),
      'administeredAt': administeredAt?.toIso8601String(),
      'status': status.name,
      'notes': notes,
    };
  }

  factory BloodProductUnit.fromMap(Map<String, dynamic> map) {
    return BloodProductUnit(
      id: map['id'] as String,
      caseId: map['caseId'] as String,
      productType: BloodProductType.values.firstWhere(
        (e) => e.name == map['productType'],
        orElse: () => BloodProductType.ES,
      ),
      barcode: map['barcode'] as String,
      lotNumber: map['lotNumber'] as String,
      expiryDate: DateTime.parse(map['expiryDate'] as String),
      bloodGroup: BloodGroup.values.firstWhere(
        (e) => e.name == map['bloodGroup'],
        orElse: () => BloodGroup.unknown,
      ),
      rhFactor: RhFactor.values.firstWhere(
        (e) => e.name == map['rhFactor'],
        orElse: () => RhFactor.unknown,
      ),
      dispatchedBy: map['dispatchedBy'] as String? ?? '',
      registeredAt: DateTime.parse(map['registeredAt'] as String),
      receivedAt: map['receivedAt'] != null
          ? DateTime.parse(map['receivedAt'] as String)
          : null,
      administeredAt: map['administeredAt'] != null
          ? DateTime.parse(map['administeredAt'] as String)
          : null,
      status: ProductStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ProductStatus.registered,
      ),
      notes: map['notes'] as String?,
    );
  }
}
