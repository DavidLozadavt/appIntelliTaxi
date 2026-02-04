class ActivationCompanyUser {
  final int id;
  final int userId;
  final int stateId;
  final int companyId;
  final String fechaInicio;
  final String fechaFin;
  final String createdAt;
  final String updatedAt;

  ActivationCompanyUser({
    required this.id,
    required this.userId,
    required this.stateId,
    required this.companyId,
    required this.fechaInicio,
    required this.fechaFin,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ActivationCompanyUser.fromJson(Map<String, dynamic> json) {
    return ActivationCompanyUser(
      id: int.parse(json['id'].toString()),
      userId: int.parse(json['user_id'].toString()),
      stateId: int.parse(json['state_id'].toString()),
      companyId: int.parse(json['company_id'].toString()),
      fechaInicio: json['fechaInicio'],
      fechaFin: json['fechaFin'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'state_id': stateId,
        'company_id': companyId,
        'fechaInicio': fechaInicio,
        'fechaFin': fechaFin,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
