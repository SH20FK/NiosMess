class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.ticketType,
    required this.subject,
    required this.body,
    this.status = 'open',
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String ticketType; // 'support' or 'copyright'
  final String subject;
  final String body;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCopyright => ticketType == 'copyright';

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as int? ?? 0,
      ticketType: json['ticket_type'] as String? ?? 'support',
      subject: json['subject'] as String? ?? '',
      body: json['body'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'ticket_type': ticketType,
      'subject': subject,
      'body': body,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
