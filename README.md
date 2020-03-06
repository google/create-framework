# Create

A reactive programming framework built with Dart and Flutter,
along with demo applications.

This is not an officially supported Google product.

Generic components:
- [elements](lib/src/elements/):
  a library of core reactive datatypes (interfaces)
- [views](lib/src/views/):
  abstract widgets: view = (observable) model + (observable) style
- [flutterviews](lib/src/flutterviews/):
  view bindings implemented with [Flutter](http://flutter.io)
- [datastore](lib/src/datastore/):
  datastore with live query support and synchonization via cloud service

Applications:
- [counter](lib/src/counter/):
  counter application written using the framework
- [briefing](lib/src/briefing/):
  information consumption interface
- [create](lib/src/create/):
  app builder that is in the process of being bootstrapped
