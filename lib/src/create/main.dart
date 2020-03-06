// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../config.dart';
import '../../elements.dart';
import '../../datastore.dart';
import '../../firestore.dart';
import '../../flutterviews.dart';
import '../../sync.dart';
import '../../views.dart';
import '../sync/firebasetransport.dart';

import 'createdata.dart';
import 'createinit.dart';
import 'createapp.dart';
import 'hackernews.dart';

const CREATE_COLLECTION = 'create';

final String syncUri = 'http://SCRUBBED.appspot.com/data?id=$CREATE_VERSION';

const bool RESET_DATASTORE = false;

void createMain() {
  InMemoryDatastore<CompositeData> datastore = InMemoryDatastore<CompositeData>(allCreateTypes);
  Ref<bool> dataReady = Boxed<bool>(false);
  CreateDataset dataset = CreateDataset(DEMOAPP_NAMESPACE);

  switch (APPLICATION) {
    case ApplicationConfig.CREATE_LEGACY:
      DataTransport transport = HttpTransport(syncUri);
      if (!RESET_DATASTORE) {
        DataSyncer(datastore, transport).initialize(dataReady, INITIAL_STATE);
      } else {
        datastore.addAll(dataset.makeInitialData(), datastore.version);
        dataReady.value = true;
        DataSyncer(datastore, transport).push();
      }
      break;

    case ApplicationConfig.CREATE_RESET:
      dataset.setDatastore(initItemRecordSet());
      datastore.addAll(dataset.makeInitialData(), datastore.version);
      dataReady.value = true;
      //DataSyncer(datastore, HttpTransport(syncUri)).push();
      break;

    case ApplicationConfig.CREATE_FIRESTORE:
      print('TODO: update INITIAL_STATE');
      DataSyncer(datastore, null).initialize(dataReady, INITIAL_STATE);
      DatastoreSync(datastore, CREATE_COLLECTION).setup();
      break;

    case ApplicationConfig.CREATE_DEMO:
      datastore = initItemRecordSet();
      datastore.dataTypes.addAll(allCreateTypes);
      dataset.setDatastore(datastore);
      datastore.addAll(dataset.makeInitialData(), datastore.version);
      //datastore.dump();
      DataSyncer(datastore, FirebaseTransport()).push();
      dataReady.value = true;
      break;

    default:
      throw StateError('Unknown app $APPLICATION');
  }

  ApplicationView appView = CreateApp(datastore, dataReady, dataset).view;
  FlutterApp(appView).run();
}

void main() {
  createMain();
}
