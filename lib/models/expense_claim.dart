class ExpenseClaim {
  final String id;
  final String userId; // Added this field
  final String merchantName;
  final double amount;
  final String date;
  final String status;
  final String auditReason;
  final String currency;
  final String? location;
  final String? justification;
  final String? imageUrl;
  final String? policySnippet;

  ExpenseClaim({
    required this.id,
    required this.userId, // Added this
    required this.merchantName,
    required this.amount,
    required this.date,
    required this.status,
    required this.auditReason,
    this.currency = 'USD',
    this.location,
    this.justification,
    this.imageUrl,
    this.policySnippet,
  });

  factory ExpenseClaim.fromJson(Map<String, dynamic> json) {
    return ExpenseClaim(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? 'unknown', // Added this mapping
      merchantName: json['merchant_name'] ?? 'Unknown Merchant',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['expense_date'] ?? 'N/A',
      status: json['status'] ?? 'pending',
      auditReason: json['audit_reason'] ?? 'Pending AI Review',
      currency: json['currency'] ?? 'USD',
      location: json['location'],
      justification: json['justification'],
      imageUrl: json['image_url'],
      policySnippet: json['policy_snippet'],
    );
  }
}