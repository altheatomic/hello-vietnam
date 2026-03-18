import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';

class DeleteUserDataPage extends StatefulWidget {
  const DeleteUserDataPage({super.key});

  @override
  State<DeleteUserDataPage> createState() => _DeleteUserDataPageState();
}

enum _DeleteDataStep {
  selectTrip,
  reviewData,
  confirmDeletion,
  success,
}

class _DeleteUserDataPageState extends State<DeleteUserDataPage> {
  static const Color _primaryBlue = Color(0xFF81D4FA);
  static const Color _textDark = Color(0xFF151515);
  static const double _buttonHeight = 52;

  static const List<_TripOption> _trips = <_TripOption>[
    _TripOption(id: 'trip-1', title: 'Trip 1'),
    _TripOption(id: 'trip-2', title: 'Trip 2'),
    _TripOption(id: 'trip-3', title: 'Trip 3'),
  ];

  static const List<_DeleteDataOption> _dataOptions = <_DeleteDataOption>[
    _DeleteDataOption(
      id: 'travel-preferences',
      title: 'Travel preferences for recommendations',
      description: 'Data about your preferences (including bookmarked places, cuisines,...)',
      icon: Icons.favorite_border_rounded,
    ),
    _DeleteDataOption(
      id: 'ai-image',
      title: 'AI image',
      description: 'Images that you uploaded for AI identification',
      icon: Icons.auto_awesome_outlined,
    ),
    _DeleteDataOption(
      id: 'uploaded-media',
      title: 'Uploaded images and media',
      description: 'Images that you uploaded on other functions such as forum',
      icon: Icons.perm_media_outlined,
    ),
  ];

  _DeleteDataStep _step = _DeleteDataStep.selectTrip;
  final Set<String> _selectedTripIds = <String>{};
  final Set<String> _selectedDataIds = <String>{};

  void _showRequiredMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleTopBack() {
    switch (_step) {
      case _DeleteDataStep.selectTrip:
        context.pop();
        return;
      case _DeleteDataStep.reviewData:
        setState(() {
          _step = _DeleteDataStep.selectTrip;
        });
        return;
      case _DeleteDataStep.confirmDeletion:
        setState(() {
          _step = _DeleteDataStep.reviewData;
        });
        return;
      case _DeleteDataStep.success:
        context.pop();
        return;
    }
  }

  void _toggleTrip(String id) {
    setState(() {
      if (_selectedTripIds.contains(id)) {
        _selectedTripIds.remove(id);
      } else {
        _selectedTripIds.add(id);
      }
    });
  }

  void _toggleDataSelection(String id) {
    setState(() {
      if (_selectedDataIds.contains(id)) {
        _selectedDataIds.remove(id);
      } else {
        _selectedDataIds.add(id);
      }
    });
  }

  void _continueFromTripSelection() {
    if (_selectedTripIds.isEmpty) {
      _showRequiredMessage('Please select at least one trip');
      return;
    }

    setState(() {
      _step = _DeleteDataStep.reviewData;
    });
  }

  void _continueFromReview() {
    if (_selectedDataIds.isEmpty) {
      _showRequiredMessage('Please select data to delete');
      return;
    }

    setState(() {
      _step = _DeleteDataStep.confirmDeletion;
    });
  }

  void _deleteData() {
    setState(() {
      _step = _DeleteDataStep.success;
    });
  }

  void _finishDeletionFlow() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? rootContext = rootNavigatorKey.currentContext;
      if (rootContext == null) {
        return;
      }
      GoRouter.of(rootContext).go(AppRoutes.home);
    });
  }

  void _onBackPressedInBody() {
    if (_step == _DeleteDataStep.selectTrip) {
      context.pop();
      return;
    }

    if (_step == _DeleteDataStep.reviewData) {
      setState(() {
        _step = _DeleteDataStep.selectTrip;
      });
      return;
    }

    if (_step == _DeleteDataStep.confirmDeletion) {
      setState(() {
        _step = _DeleteDataStep.reviewData;
      });
      return;
    }

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_step == _DeleteDataStep.selectTrip || _step == _DeleteDataStep.success) {
          return true;
        }

        if (_step == _DeleteDataStep.reviewData) {
          setState(() {
            _step = _DeleteDataStep.selectTrip;
          });
          return false;
        }

        setState(() {
          _step = _DeleteDataStep.reviewData;
        });
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _HeaderBar(onBack: _handleTopBack),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 230),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _buildStepView(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepView() {
    switch (_step) {
      case _DeleteDataStep.selectTrip:
        return _buildTripSelectionStep();
      case _DeleteDataStep.reviewData:
        return _buildReviewDataStep();
      case _DeleteDataStep.confirmDeletion:
        return _buildConfirmDeletionStep();
      case _DeleteDataStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildTripSelectionStep() {
    return ListView(
      key: const ValueKey<String>('trip-selection'),
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 118),
      children: <Widget>[
        const Text(
          'Trip itinerary and plans',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Choose trips that you want to delete.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF2B2B2B),
          ),
        ),
        const SizedBox(height: 24),
        ..._trips.map((trip) {
          final bool selected = _selectedTripIds.contains(trip.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SelectableRow(
              icon: Icons.calendar_today_outlined,
              title: trip.title,
              selected: selected,
              onTap: () => _toggleTrip(trip.id),
            ),
          );
        }),
        const SizedBox(height: 32),
        _ActionButtons(
          backLabel: 'Back',
          nextLabel: 'Continue',
          onBack: _onBackPressedInBody,
          onNext: _continueFromTripSelection,
        ),
      ],
    );
  }

  Widget _buildReviewDataStep() {
    return ListView(
      key: const ValueKey<String>('review-data'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 118),
      children: <Widget>[
        const Text(
          'Review Your Trip Data',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Choose what data you want to delete.\n'
          'This will only affect this completed trip.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF2B2B2B),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 24),
        ..._dataOptions.map((item) {
          final bool selected = _selectedDataIds.contains(item.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SelectableRow(
                  icon: item.icon,
                  title: item.title,
                  selected: selected,
                  onTap: () => _toggleDataSelection(item.id),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFA5A5A5),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),
        _ActionButtons(
          backLabel: 'Back',
          nextLabel: 'Continue',
          onBack: _onBackPressedInBody,
          onNext: _continueFromReview,
        ),
      ],
    );
  }

  Widget _buildConfirmDeletionStep() {
    final List<_DeleteDataOption> selectedItems = _dataOptions
        .where((item) => _selectedDataIds.contains(item.id))
        .toList();

    return ListView(
      key: const ValueKey<String>('confirm'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 118),
      children: <Widget>[
        const Text(
          'Confirm Data Deletion',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'You are about to delete the selected personal data related\nto this trip.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF2B2B2B),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        ...selectedItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SummaryRow(
              icon: item.icon,
              title: item.title,
            ),
          );
        }),
        if (selectedItems.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 18),
            child: Text(
              'No data selected yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E8E),
              ),
            ),
          ),
        const SizedBox(height: 14),
        _ActionButtons(
          backLabel: 'Back',
          nextLabel: 'Delete',
          onBack: _onBackPressedInBody,
          onNext: _deleteData,
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return ListView(
      key: const ValueKey<String>('success'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 118),
      children: <Widget>[
        const SizedBox(height: 14),
        Center(
          // Placeholder icon: replace this block with your image widget
          // after you share the image folder path.
          child: Container(
            width: 170,
            height: 170,
            decoration: const BoxDecoration(
              color: _primaryBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 105,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Data Deleted Successfully !',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Your selected personal data has been deleted.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF2B2B2B),
          ),
        ),
        const SizedBox(height: 26),
        Center(
          child: SizedBox(
            width: 190,
            height: _buttonHeight,
            child: ElevatedButton(
              onPressed: _finishDeletionFlow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Ok'),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 40,
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Color(0xFF1B1B1B),
                    size: 30,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Personal Data',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0xFF121212),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF72C9F2) : const Color(0xFFD8D8D8),
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22, color: const Color(0xFF232323)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _ChoiceCircle(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8D8D8)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 22, color: const Color(0xFF232323)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1F1F1F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.backLabel,
    required this.nextLabel,
    required this.onBack,
    required this.onNext,
  });

  final String backLabel;
  final String nextLabel;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: _DeleteUserDataPageState._buttonHeight,
            child: ElevatedButton(
              onPressed: onBack,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _DeleteUserDataPageState._primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(backLabel),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: _DeleteUserDataPageState._buttonHeight,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _DeleteUserDataPageState._primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(nextLabel),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceCircle extends StatelessWidget {
  const _ChoiceCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 26,
      height: 26,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? const Color(0xFF72C9F2) : const Color(0xFFD0D0D0),
          width: selected ? 1.6 : 1.2,
        ),
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: selected ? 1 : 0,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF72C9F2),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _TripOption {
  const _TripOption({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;
}

class _DeleteDataOption {
  const _DeleteDataOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
}
