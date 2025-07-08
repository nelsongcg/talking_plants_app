import 'package:flutter/material.dart';

/// ------------------------------------------------------------------
/// Brand-coloured call-to-action button used across the app.
/// • fills the available width
/// • rounded 12-px corners (matches Figma)
/// • supports a built-in loading spinner
/// ------------------------------------------------------------------
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
  });

  /// Text shown on the button when not loading.
  final String label;

  /// Callback when tapped.
  final VoidCallback? onPressed;

  /// If `false` the button is greyed-out & disabled.
  final bool enabled;

  /// When `true` shows a CircularProgressIndicator and ignores taps.
  final bool loading;

  bool get _isDisabled => loading || !enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isDisabled ? cs.outline : cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: ts.labelLarge,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(label),
      ),
    );
  }
}
