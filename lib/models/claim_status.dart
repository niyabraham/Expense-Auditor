enum ClaimStatus {
  pending,
  approved,
  flagged,
  rejected
}

extension ClaimStatusExtension on ClaimStatus {
  static ClaimStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return ClaimStatus.approved;
      case 'flagged':
        return ClaimStatus.flagged;
      case 'rejected':
        return ClaimStatus.rejected;
      default:
        return ClaimStatus.pending;
    }
  }

  String get name {
    switch (this) {
      case ClaimStatus.approved:
        return 'approved';
      case ClaimStatus.flagged:
        return 'flagged';
      case ClaimStatus.rejected:
        return 'rejected';
      case ClaimStatus.pending:
        return 'pending';
    }
  }
}
