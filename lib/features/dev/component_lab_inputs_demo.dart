part of 'component_lab_view.dart';

/// One editable example of every AppTextField variant. No production state.
class _InputsDemo extends StatefulWidget {
  const _InputsDemo();

  @override
  State<_InputsDemo> createState() => _InputsDemoState();
}

class _InputsDemoState extends State<_InputsDemo> {
  final _entry = TextEditingController();
  final _plain = TextEditingController();
  final _search = TextEditingController();
  final _email = TextEditingController();
  final _number = TextEditingController();
  final _password = TextEditingController();
  final _notes = TextEditingController();
  final _entryFocus = FocusNode();

  @override
  void dispose() {
    _entry.dispose();
    _plain.dispose();
    _search.dispose();
    _email.dispose();
    _number.dispose();
    _password.dispose();
    _notes.dispose();
    _entryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabExample(
          title: 'Input / Quick entry / Adjacent action / M',
          flutterMapping: 'AppQuickEntryRow → AppTextField + AppButton.primary',
          variant: 'text + action',
          size: 'M',
          state: 'enabled',
          note: 'Painted field and button: identical 48px height and 14px radius.',
          fullWidth: true,
          child: AppQuickEntryRow(
            controller: _entry,
            focusNode: _entryFocus,
            hintText: 'Add a record',
            actionLabel: 'Start',
            actionIcon: Icons.play_arrow_rounded,
            onAction: _mockAction,
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Input / Text / M',
          flutterMapping: 'AppTextField(variant: text)',
          variant: 'text',
          size: 'M',
          state: 'enabled',
          fullWidth: true,
          child: AppTextField(
            controller: _plain,
            labelText: 'Name',
            hintText: 'Name',
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Input / Search / M',
          flutterMapping: 'AppTextField(variant: search)',
          variant: 'search',
          size: 'M',
          state: 'enabled',
          fullWidth: true,
          child: AppTextField(
            controller: _search,
            variant: AppTextFieldVariant.search,
            hintText: 'Search',
            textInputAction: TextInputAction.search,
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Input / Email / M',
          flutterMapping: 'AppTextField(variant: email)',
          variant: 'email',
          size: 'M',
          state: 'enabled',
          fullWidth: true,
          child: AppTextField(
            controller: _email,
            variant: AppTextFieldVariant.email,
            hintText: 'Email',
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Input / Number / M',
          flutterMapping: 'AppTextField(variant: number)',
          variant: 'number',
          size: 'M',
          state: 'enabled',
          fullWidth: true,
          child: AppTextField(
            controller: _number,
            variant: AppTextFieldVariant.number,
            hintText: 'Minutes',
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Input / Password / M',
          flutterMapping: 'AppTextField(variant: password)',
          variant: 'password',
          size: 'M',
          state: 'enabled',
          fullWidth: true,
          child: AppTextField(
            controller: _password,
            variant: AppTextFieldVariant.password,
            hintText: 'Password',
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Input / Multiline',
          flutterMapping: 'AppTextField(variant: multiline)',
          variant: 'multiline',
          state: 'enabled',
          fullWidth: true,
          child: AppTextField(
            controller: _notes,
            variant: AppTextFieldVariant.multiline,
            hintText: 'Notes',
            minLines: 2,
            maxLines: 5,
          ),
        ),
      ],
    );
  }
}
