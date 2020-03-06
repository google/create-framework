// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';
import '../../views.dart';

class CounterData extends BaseZone {
  CounterData() : super(null, 'counterdata');

  // State
  final Ref<int> counter = new Boxed<int>(68);

  final Ref<int> increaseBy = new Boxed<int>(1);

  // Business logic
  Operation get increaseValue => makeOperation(() {
        counter.value = counter.value + increaseBy.value;
      });

  ReadRef<String> get describeState => new ReactiveFunction<int, String>(
      counter, (int counterValue) => 'The counter value is $counterValue', this);
}

class CounterApp extends BaseZone {
  final CounterData datastore;
  ApplicationView view;

  CounterApp(this.datastore) : super(null, 'counterapp') {
    mainViewPadding = true;
    View mainView = new ColumnView(new ImmutableList<View>([
      new LabelView(datastore.describeState, new Constant<Style>(BODY2_STYLE)),
      new ButtonView(new Constant<String>('Increase the counter value'),
          new Constant<Style>(BUTTON_STYLE), new Constant<Operation>(datastore.increaseValue))
    ]));
    view = ApplicationView(Constant<View>(mainView), new Constant<String>('Create!'),
        drawer: Constant<DrawerView>(makeDrawer()));
  }

  DrawerView makeDrawer() {
    return new DrawerView(new ImmutableList<View>([
      new HeaderView(new Constant<String>('Counter Demo')),
      new ItemView(
          new Constant<String>('Increase by one'),
          new Constant<IconId>(EXPOSURE_PLUS_1_ICON),
          new Constant<bool>(datastore.increaseBy.value == 1),
          new Constant<Operation>(increaseByOne)),
      new ItemView(
          new Constant<String>('Increase by two'),
          new Constant<IconId>(EXPOSURE_PLUS_2_ICON),
          new Constant<bool>(datastore.increaseBy.value == 2),
          new Constant<Operation>(increaseByTwo)),
      new DividerView(),
      new ItemView(new Constant<String>('Help & Feedback'), new Constant<IconId>(HELP_ICON),
          new Constant<bool>(false), null),
    ]));
  }

  // UI Logic
  Operation get increaseByOne => makeOperation(() {
        datastore.increaseBy.value = 1;
      });

  Operation get increaseByTwo => makeOperation(() {
        datastore.increaseBy.value = 2;
      });
}
