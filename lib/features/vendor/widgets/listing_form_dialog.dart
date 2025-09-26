import 'package:flutter/material.dart';
import '/features/vendor/widgets/listing_form_stepper.dart';
import '../../listings/models/bundle_listing_model.dart';

class ListingFormDialog extends StatelessWidget {
  final BundleListing? listing;
  final Function(Map<String, dynamic>) onSubmit;
  final Function()? onSaveDraft;

  const ListingFormDialog({
    Key? key,
    this.listing,
    required this.onSubmit,
    this.onSaveDraft,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: screenSize.width * 0.95,
        height: screenSize.height * 0.85,
        constraints: BoxConstraints(
          minWidth: 320,
          maxWidth: 1200,
          minHeight: 600,
          maxHeight: screenSize.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.primaryColorDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      listing == null ? 'Create New Listing' : 'Edit Listing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            
            // Form content with padding
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: ListingFormStepper(
                  listing: listing,
                  onSubmit: onSubmit,
                  onSaveDraft: onSaveDraft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}