// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';

class _RequestInfo {
  final void Function(Operation) start;
  final Operation onDone;
  final Zone zone;
  final Priority priority;
  final int requestNumber;

  _RequestInfo(this.start, this.onDone, this.zone, this.priority, this.requestNumber);

  String toString() => 'Request #$requestNumber $priority';
}

class RequestThrotller {
  int maxRequests;
  bool logRequests;
  List<List<_RequestInfo>> requestQueues = [];
  int nextRequestNumber = 0;
  int requestsInFlight = 0;

  RequestThrotller(this.maxRequests, this.logRequests) {
    for (int i = 0; i < Priority.values.length; ++i) {
      requestQueues.add([]);
    }
  }

  void addRequest(_RequestInfo request) {
    requestQueues[request.priority.index].add(request);
  }

  _RequestInfo nextRequest() {
    for (int i = 0; i < Priority.values.length; ++i) {
      if (requestQueues[i].isNotEmpty) {
        return requestQueues[i].removeAt(0);
      }
    }

    return null;
  }

  void schedule(void Function(Operation) start, Operation onDone, Zone zone, Priority priority) {
    _RequestInfo request = _RequestInfo(start, onDone, zone, priority, nextRequestNumber++);
    if (logRequests) {
      print('Scheduled $request');
    }
    addRequest(request);
    processPendingRequests();
  }

  void processPendingRequests() {
    while (requestsInFlight < maxRequests) {
      _RequestInfo request = nextRequest();
      if (request == null) {
        return;
      }

      if (logRequests) {
        print('Started $request');
      }
      ++requestsInFlight;
      Operation requestDone = request.zone.makeOperation(() {
        --requestsInFlight;
        if (request.onDone != null) {
          request.onDone.scheduleAction();
        }
        if (logRequests) {
          print('Ended $request');
        }
        processPendingRequests();
      });
      request.start(requestDone);
    }
  }
}
