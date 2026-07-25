import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:hellovietnam/features/location/data/device_location_service.dart';
import 'package:hellovietnam/features/location/data/location_preference_repository.dart';
import 'package:hellovietnam/features/location/domain/user_location_preference.dart';

class QuickLocationFlow {
  QuickLocationFlow({
    DeviceLocationService? deviceLocationService,
    UserLocationPreferenceRepository? preferenceRepository,
  }) : _deviceLocationService =
           deviceLocationService ?? DeviceLocationService(),
       _preferenceRepository =
           preferenceRepository ?? UserLocationPreferenceRepository();

  final DeviceLocationService _deviceLocationService;
  final UserLocationPreferenceRepository _preferenceRepository;

  Future<void> start(BuildContext context) async {
    if (!AuthRepository.instance.isLoggedIn) {
      final bool shouldLogin = await _showSignInDialog(context);
      if (!context.mounted) return;
      if (shouldLogin) {
        context.push(AppRoutes.login);
      }
      return;
    }

    final _LocationDraft? draft = await _captureGpsDraft(context);
    if (!context.mounted || draft == null) return;

    await _confirmAndPersist(context, draft);
  }

  Future<_LocationDraft?> _captureGpsDraft(BuildContext context) async {
    final LocationPermission initialPermission = await _deviceLocationService
        .checkPermission();
    if (!context.mounted) return null;

    LocationPermission permission = initialPermission;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final _PermissionPromptChoice choice = await _showPermissionPurposeDialog(
        context,
      );
      if (!context.mounted) return null;

      if (choice == _PermissionPromptChoice.manual) {
        return _openManualEditor(
          context,
          seed: null,
          source: LocationSource.manual,
        );
      }
      if (choice == _PermissionPromptChoice.cancel) {
        return null;
      }

      permission = await _deviceLocationService.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission was denied. You can still enter location manually.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return _openManualEditor(
        context,
        seed: null,
        source: LocationSource.manual,
      );
    }

    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return null;
      final _PermissionBlockedChoice blockedChoice =
          await _showPermissionBlockedDialog(context);
      if (!context.mounted) return null;

      if (blockedChoice == _PermissionBlockedChoice.settings) {
        await _deviceLocationService.openAppSettings();
      } else if (blockedChoice == _PermissionBlockedChoice.manual) {
        return _openManualEditor(
          context,
          seed: null,
          source: LocationSource.manual,
        );
      }
      return null;
    }

    final bool serviceEnabled = await _deviceLocationService
        .isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return null;
      final _ServiceDisabledChoice serviceChoice =
          await _showServiceDisabledDialog(context);
      if (!context.mounted) return null;

      if (serviceChoice == _ServiceDisabledChoice.settings) {
        await _deviceLocationService.openLocationSettings();
      } else if (serviceChoice == _ServiceDisabledChoice.manual) {
        return _openManualEditor(
          context,
          seed: null,
          source: LocationSource.manual,
        );
      }
      return null;
    }

    try {
      final ResolvedLocationData gpsData = await _deviceLocationService
          .getCurrentGpsLocation();
      return _LocationDraft(
        latitude: gpsData.latitude,
        longitude: gpsData.longitude,
        approxAddress: gpsData.approxAddress,
        provinceCity: gpsData.provinceCity,
        source: LocationSource.gps,
      );
    } catch (_) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to detect GPS location right now. You can retry or enter location manually.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return _openManualEditor(
        context,
        seed: null,
        source: LocationSource.manual,
      );
    }
  }

  Future<void> _savePreference(
    BuildContext context,
    _LocationDraft draft,
  ) async {
    try {
      await _preferenceRepository.upsertPreference(
        UserLocationPreference(
          latitude: draft.latitude,
          longitude: draft.longitude,
          approxAddress: draft.approxAddress,
          provinceCity: draft.provinceCity,
          locationSource: draft.source,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Save location failed. Please sync database migration, then retry.\n$error',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmAndPersist(
    BuildContext context,
    _LocationDraft draft,
  ) async {
    _LocationDraft? current = draft;

    while (current != null) {
      if (!context.mounted) return;
      final _ConfirmationAction action = await _showConfirmationSheet(
        context,
        current,
      );
      if (!context.mounted) return;

      switch (action) {
        case _ConfirmationAction.confirm:
          await _savePreference(context, current);
          return;
        case _ConfirmationAction.manual:
          current = await _openManualEditor(
            context,
            seed: current,
            source: LocationSource.manual,
          );
          break;
        case _ConfirmationAction.cancel:
          return;
      }
    }
  }

  Future<_ConfirmationAction> _showConfirmationSheet(
    BuildContext context,
    _LocationDraft draft,
  ) async {
    final _ConfirmationAction?
    action = await showModalBottomSheet<_ConfirmationAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Confirm your location',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Address', value: draft.approxAddress),
                const SizedBox(height: 8),
                _InfoRow(label: 'Province/City', value: draft.provinceCity),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Coordinates',
                  value: draft.latitude != null && draft.longitude != null
                      ? '${draft.latitude!.toStringAsFixed(6)}, ${draft.longitude!.toStringAsFixed(6)}'
                      : 'Not provided',
                ),
                const SizedBox(height: 8),
                _InfoRow(label: 'Source', value: draft.source.dbValue),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(
                      sheetContext,
                    ).pop(_ConfirmationAction.manual),
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: const Text('Manual'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(
                      sheetContext,
                    ).pop(_ConfirmationAction.confirm),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Confirm and Save'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(
                    sheetContext,
                  ).pop(_ConfirmationAction.cancel),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );

    return action ?? _ConfirmationAction.cancel;
  }

  Future<_LocationDraft?> _openManualEditor(
    BuildContext context, {
    required _LocationDraft? seed,
    required LocationSource source,
  }) async {
    final TextEditingController addressController = TextEditingController(
      text: seed?.approxAddress ?? '',
    );
    final TextEditingController provinceController = TextEditingController(
      text: seed?.provinceCity ?? '',
    );
    final TextEditingController latitudeController = TextEditingController(
      text: seed?.latitude?.toStringAsFixed(6) ?? '',
    );
    final TextEditingController longitudeController = TextEditingController(
      text: seed?.longitude?.toStringAsFixed(6) ?? '',
    );

    final _LocationDraft? result = await showDialog<_LocationDraft>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Enter Location Manually'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Approx address',
                    hintText: 'Street / area',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: provinceController,
                  decoration: const InputDecoration(
                    labelText: 'Province / city',
                    hintText: 'Hue, Da Nang, Ha Noi...',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: latitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: longitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String address = addressController.text.trim();
                final String province = provinceController.text.trim();
                final double? lat = double.tryParse(
                  latitudeController.text.trim(),
                );
                final double? lng = double.tryParse(
                  longitudeController.text.trim(),
                );

                if (address.isEmpty && province.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter at least an address or a province/city.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(
                  _LocationDraft(
                    latitude: lat,
                    longitude: lng,
                    approxAddress: address.isEmpty
                        ? 'Manual location'
                        : address,
                    provinceCity: province.isEmpty ? 'Unknown area' : province,
                    source: source,
                  ),
                );
              },
              child: const Text('Use Manual Location'),
            ),
          ],
        );
      },
    );

    addressController.dispose();
    provinceController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();

    return result;
  }

  Future<bool> _showSignInDialog(BuildContext context) async {
    final bool? value = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Sign in required'),
          content: const Text(
            'Please sign in first to save your location preference securely.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign In'),
            ),
          ],
        );
      },
    );
    return value ?? false;
  }

  Future<_PermissionPromptChoice> _showPermissionPurposeDialog(
    BuildContext context,
  ) async {
    final _PermissionPromptChoice?
    value = await showDialog<_PermissionPromptChoice>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Allow location access'),
          content: const Text(
            'We use your location to suggest nearby places, food, activities, and local cultural content. You can also enter location manually.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_PermissionPromptChoice.manual),
              child: const Text('Enter Manually'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_PermissionPromptChoice.cancel),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_PermissionPromptChoice.continueRequest),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    return value ?? _PermissionPromptChoice.cancel;
  }

  Future<_PermissionBlockedChoice> _showPermissionBlockedDialog(
    BuildContext context,
  ) async {
    final _PermissionBlockedChoice?
    value = await showDialog<_PermissionBlockedChoice>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Location permission blocked'),
          content: const Text(
            'Location permission is permanently denied. Open app settings to enable it, or enter location manually.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_PermissionBlockedChoice.manual),
              child: const Text('Enter Manually'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_PermissionBlockedChoice.cancel),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_PermissionBlockedChoice.settings),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
    return value ?? _PermissionBlockedChoice.cancel;
  }

  Future<_ServiceDisabledChoice> _showServiceDisabledDialog(
    BuildContext context,
  ) async {
    final _ServiceDisabledChoice?
    value = await showDialog<_ServiceDisabledChoice>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('GPS is turned off'),
          content: const Text(
            'Your device location service is disabled. Enable GPS to detect your current position, or enter location manually.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_ServiceDisabledChoice.manual),
              child: const Text('Enter Manually'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_ServiceDisabledChoice.cancel),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_ServiceDisabledChoice.settings),
              child: const Text('Open GPS Settings'),
            ),
          ],
        );
      },
    );
    return value ?? _ServiceDisabledChoice.cancel;
  }
}

class _LocationDraft {
  const _LocationDraft({
    required this.approxAddress,
    required this.provinceCity,
    required this.source,
    this.latitude,
    this.longitude,
  });

  final double? latitude;
  final double? longitude;
  final String approxAddress;
  final String provinceCity;
  final LocationSource source;
}

enum _PermissionPromptChoice { continueRequest, manual, cancel }

enum _PermissionBlockedChoice { settings, manual, cancel }

enum _ServiceDisabledChoice { settings, manual, cancel }

enum _ConfirmationAction { confirm, manual, cancel }

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
