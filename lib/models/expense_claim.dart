// lib/models/expense_claim.dart

class ExpenseClaim {
  final String id;
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

  /// Factory constructor to safely parse JSON from Supabase.
  factory ExpenseClaim.fromJson(Map<String, dynamic> json) {
    return ExpenseClaim(
      id: json['id'].toString(),
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

  /// Convert back to a Map if needed (e.g., for updates)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_name': merchantName,
      'amount': amount,
      'expense_date': date,
      'status': status,
      'audit_reason': auditReason,
      'currency': currency,
      'location': location,
      'justification': justification,
      'image_url': imageUrl,
      'policy_snippet': policySnippet,
    };
  }
}
