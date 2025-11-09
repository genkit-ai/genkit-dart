import './action.dart';

class Registry {
  final Map<String, Action> _actions = {};

  String _getKey(String actionType, String name) {
    return '/$actionType/$name';
  }

  void register(Action action) {
    final key = _getKey(action.actionType, action.name);
    _actions[key] = action;
  }

  Future<Action?> get(String actionType, String name) async {
    final key = _getKey(actionType, name);
    return _actions[key];
  }
}
