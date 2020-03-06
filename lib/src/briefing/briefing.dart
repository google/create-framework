// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../config.dart';
import '../../elements.dart';
import '../../views.dart';
import '../../datastore.dart';
import 'briefingdata.dart';
import 'priorities.dart';

class BriefingApp extends BaseZone {
  ApplicationConfig appConfig;
  Datastore<CompositeData> datastore;
  final DataIdSource idSource = new RandomIdSource(BRIEFING_NAMESPACE);
  Zone zone;
  ApplicationView view;
  Ref<String> navText = Boxed<String>('');
  Ref<AddressCategory> currentAddressCategory = Boxed<AddressCategory>(AddressCategory.Person);
  Ref<ItemRecord> currentItem = Boxed<ItemRecord>(null);
  ReadRef<String> activeSearch;
  ReadRef<Category> activeCategory;
  View categoryColumn;
  Lifespan viewLifespan;
  FlexStyle mainRowStyle;
  ContainerStyle categoryStyle;
  ContainerStyle categoryStyleSelected;
  ContainerStyle expandedContainerStyle;
  ContainerStyle scoreStyle;
  ContainerStyle fromStyle;
  ContainerStyle contextStyle;
  ContainerStyle contextStyleSelected;

  BriefingApp(this.appConfig, this.datastore) : super(null, 'briefingapp') {
    zone = this;

    mainRowStyle =
        FlexStyle(idSource.nextId(), START_MAIN_AXIS, START_CROSS_AXIS, expanded: EXPANDED_STYLE);
    categoryStyle =
        ContainerStyle.symmetric(idSource.nextId(), vertical: 4.0, horizontal: 12.0, width: 120.0);
    categoryStyleSelected = ContainerStyle.symmetric(idSource.nextId(),
        vertical: 4.0, horizontal: 12.0, width: 120.0, color: LIGHT_TEAL_COLOR);
    expandedContainerStyle = ContainerStyle.all(idSource.nextId(), 0.0, expanded: EXPANDED_STYLE);
    scoreStyle = ContainerStyle.all(idSource.nextId(), 0.0, width: 26.0);
    fromStyle = ContainerStyle.all(idSource.nextId(), 0.0, width: 200.0);

    activeSearch = ReactiveFunction<String, String>(navText, normalizeSearchQuery, zone);
    activeCategory = ReactiveFunction<String, Category>(activeSearch, categoryFromSearch, zone);
    categoryColumn = renderCategoryColumn();
    contextStyle =
        ContainerStyle.symmetric(idSource.nextId(), vertical: 4.0, horizontal: 12.0, width: 170.0);
    contextStyleSelected = ContainerStyle.symmetric(idSource.nextId(),
        vertical: 4.0, horizontal: 12.0, width: 170.0, color: LIGHT_TEAL_COLOR);
    ReadRef<View> mainView = ReactiveFunction2<String, AddressCategory, View>(
        activeSearch, currentAddressCategory, renderMainView, zone);

    view = ApplicationView(mainView, Constant<String>('Create.Briefing'));
  }

  bool get _showContextPane => appConfig == ApplicationConfig.BRIEFING_GMAIL;

  Category categoryFromSearch(String search) {
    if (search.startsWith(HASH_PREFIX)) {
      search = search.substring(HASH_PREFIX.length);
    }

    for (Category category in categories) {
      if (category.id == search) {
        return category;
      }
    }
    return null;
  }

  View renderMainView(String search, AddressCategory addressCategory) {
    if (viewLifespan != null) {
      viewLifespan.dispose();
    }
    viewLifespan = makeSubSpan();

    View itemPane = renderItemPane(search, viewLifespan);
    ImmutableList<View> rowItems;
    if (_showContextPane) {
      View contextPane = renderContextPane(search, addressCategory, viewLifespan);
      rowItems = ImmutableList<View>([categoryColumn, itemPane, contextPane]);
    } else {
      rowItems = ImmutableList<View>([categoryColumn, itemPane]);
    }
    View rowView = RowView(rowItems, Constant<Style>(mainRowStyle));

    View navView = TextInput(navText, Constant<Style>(BODY1_STYLE));
    ImmutableList<View> mainItems = ImmutableList<View>([navView, rowView]);
    return ColumnView(mainItems, Constant<Style>(null));
  }

  View renderCategoryColumn() {
    List<View> rows = new List<View>();
    for (Category category in categories) {
      rows.add(renderCategory(category));
    }
    FlexStyle columnStyle = new FlexStyle(idSource.nextId(), START_MAIN_AXIS, END_CROSS_AXIS);
    return ColumnView(ImmutableList<View>(rows), Constant<Style>(columnStyle));
  }

  ReadRef<ContainerStyle> makeCategoryContainerStyle(ReadRef<bool> selected) {
    return ReactiveFunction<bool, ContainerStyle>(
        selected, (bool s) => s ? categoryStyleSelected : categoryStyle, zone);
  }

  ReadRef<bool> isActiveCategory(Category category) {
    return ReactiveFunction<Category, bool>(activeCategory, (Category c) => c == category, zone);
  }

  ReadRef<int> unreadItemCount(Category category, Lifespan lifespan) {
    return datastore.count(ItemQuery(category.toQuery, true), lifespan, UNREAD_COUNT_PRIORITY);
  }

  View renderCategory(Category category) {
    ReadRef<int> itemCount = unreadItemCount(category, zone);
    ReadRef<Style> nameStyle =
        ReactiveFunction<int, Style>(itemCount, (c) => c > 0 ? BODY1_STYLE : BODY2_STYLE, zone);
    View nameLabel = LabelView(Constant<String>(category.name), nameStyle);
    String renderCount(int count) {
      if (count == 0) {
        return '';
      } else if (count < MAX_ITEMS) {
        return count.toString();
      } else {
        return '${MAX_ITEMS - 1}+';
      }
    }

    ReadRef<String> count = ReactiveFunction<int, String>(itemCount, renderCount, zone);
    View countLabel = LabelView(count, Constant<Style>(BODY2_STYLE));
    ImmutableList<View> rowItems = ImmutableList<View>([nameLabel, countLabel]);
    FlexStyle rowStyle = new FlexStyle(idSource.nextId(), SPACE_BETWEEN_MAIN_AXIS, END_CROSS_AXIS);
    View rowView = RowView(rowItems, Constant<Style>(rowStyle));
    ReadRef<ContainerStyle> containerStyle = makeCategoryContainerStyle(isActiveCategory(category));
    Operation activateCategory = zone.makeOperation(() {
      navText.value = category.toQuery;
    });
    return ActionView(Constant<View>(ContainerView(Constant<View>(rowView), containerStyle)),
        Constant<Operation>(activateCategory));
  }

  View renderItem(ItemRecord item, Lifespan lifespan) {
    Style unreadStyle(bool unread) => unread ? BODY1_STYLE : BODY2_STYLE;
    ReadRef<Style> lineStyle = ReactiveFunction<bool, Style>(item.unread, unreadStyle, lifespan);

    View fromLabel = LabelView(item.from, lineStyle);
    View fromContainer = ContainerView(Constant<View>(fromLabel), Constant<Style>(fromStyle));

    MutableList<View> rowItems = BaseMutableList<View>([fromContainer]);

    bool noSnippet = isEmptyString(''); //item.snippet.value;
    if (noSnippet) {
      View titleLabel = LabelView(item.title, lineStyle);
      View titleContainer =
          ContainerView(Constant<View>(titleLabel), Constant<Style>(expandedContainerStyle));
      rowItems.add(titleContainer);
    } else {
      View titleLabel = LabelView(item.title, lineStyle);
      rowItems.add(titleLabel);
      ReadRef<String> snippet =
          ReactiveFunction<String, String>(Constant<String>('snippet'), (s) => ' - $s', lifespan);
      View snippetLabel = LabelView(snippet, Constant<Style>(BODY2_STYLE));
      View snippetContainer =
          ContainerView(Constant<View>(snippetLabel), Constant<Style>(expandedContainerStyle));
      rowItems.add(snippetContainer);
    }

    FlexStyle rowStyle =
        new FlexStyle(idSource.nextId(), SPACE_BETWEEN_MAIN_AXIS, CENTER_CROSS_AXIS, height: 28.0);
    View itemRow = RowView(rowItems, Constant<Style>(rowStyle));
    Operation itemAction = zone.makeOperation(() {
      if (currentItem.value == item) {
        currentItem.value = null;
        // We mark the item as unread so we can debug read->unread transitions
        item.unread.value = true;
      } else {
        currentItem.value = item;
        item.unread.value = false;
      }
    });
    return ActionView(Constant<View>(itemRow), Constant<Operation>(itemAction));
  }

  View renderCurrentItem(ItemRecord item) {
    String description = 'Id: ${item.dataId}\n' +
        'From: ${item.from.value}\n' +
        'Title: ${item.title.value}\n' +
        'Url: ${item.url.value}\n' +
        'Unread: ${item.unread.value}\n'
            'Addresses: ';
    if (item.addresses.size.value == 0) {
      description += '[]';
    } else {
      String displayAddresses = item.addresses.elements.map((Address a) => '  $a\n').join();
      description += '[\n$displayAddresses]';
    }

    View text = LabelView(Constant<String>(description), Constant<Style>(CAPTION_STYLE));
    View itemBody = ContainerView(
        Constant<View>(text), Constant<Style>(ContainerStyle.all(idSource.nextId(), 8.0)));
    Operation itemBodyAction = zone.makeOperation(() {
      currentItem.value = null;
    });
    return ActionView(Constant<View>(itemBody), Constant<Operation>(itemBodyAction));
  }

  List<View> renderItemColumn(ItemRecord item, Lifespan lifespan) {
    if (currentItem.value == item) {
      return [renderItem(item, lifespan), renderCurrentItem(item), DividerView(0.0)];
    } else {
      return [renderItem(item, lifespan), DividerView(0.0)];
    }
  }

  List<View> _renderItemViews(ReadList<ItemRecord> itemList, Lifespan lifespan) {
    List<View> itemViews = [];
    for (ItemRecord item in itemList.elements) {
      Style unreadStyle(bool unread) =>
          unread ? null : new FlexStyle(idSource.nextId(), null, null, color: LIGHT_GREY_COLOR);
      ReadRef<Style> columnStyle =
          ReactiveFunction<bool, Style>(item.unread, unreadStyle, lifespan);
      MutableList<View> columnItems = BaseMutableList<View>(renderItemColumn(item, lifespan));
      Operation updateItem =
          zone.makeOperation(() => columnItems.replaceWith(renderItemColumn(item, lifespan)));
      item.from.observeRef(updateItem, lifespan);
      item.title.observeRef(updateItem, lifespan);
      item.unread.observeRef(updateItem, lifespan);
      currentItem.observeRef(updateItem, lifespan);
      itemViews.add(ColumnView(columnItems, columnStyle));
    }
    return itemViews;
  }

  View renderItemPane(String search, Lifespan lifespan) {
    ReadList<ItemRecord> itemList = datastore
        .runQuery(ItemQuery(search, false), lifespan, ITEM_LIST_PRIORITY)
        .cast<ItemRecord>();
    List<View> renderItemViews = _renderItemViews(itemList, lifespan);
    MutableList<View> columnViews = BaseMutableList<View>(renderItemViews);
    Operation updateColumn =
        zone.makeOperation(() => columnViews.replaceWith(_renderItemViews(itemList, lifespan)));
    itemList.observe(updateColumn, lifespan);
    FlexStyle columnStyle =
        new FlexStyle(idSource.nextId(), null, null, expanded: DOUBLE_EXPANDED_LIST_VIEW_STYLE);
    return ColumnView(columnViews, Constant<Style>(columnStyle));
  }

  ReadRef<ContainerStyle> makeContextContainerStyle(ReadRef<bool> selected) {
    return ReactiveFunction<bool, ContainerStyle>(
        selected, (bool s) => s ? contextStyleSelected : contextStyle, zone);
  }

  View _renderAddress(
      ReadRef<String> name, ReadRef<bool> selected, Operation activate, Lifespan lifespan) {
    Style selectedStyle(bool selected) => selected ? BODY1_STYLE : BODY2_STYLE;
    ReadRef<Style> nameStyle = ReactiveFunction<bool, Style>(selected, selectedStyle, lifespan);
    View nameLabel = LabelView(name, nameStyle);
    ReadRef<ContainerStyle> containerStyle = makeContextContainerStyle(selected);
    // TODO: move operation constructor to the caller
    return ActionView(Constant<View>(ContainerView(Constant<View>(nameLabel), containerStyle)),
        Constant<Operation>(activate));
  }

  View _renderAddressCategory(AddressCategory addressCategory, String name, Lifespan lifespan) {
    Operation selectCategory = zone.makeOperation(() {
      currentAddressCategory.value = addressCategory;
    });
    return _renderAddress(Constant<String>(name), Constant<bool>(true), selectCategory, lifespan);
  }

  String _sectionName(AddressCategory addressCategory) {
    switch (addressCategory) {
      case AddressCategory.Person:
        return 'People';
      case AddressCategory.Group:
        return 'Groups';
      case AddressCategory.Source:
        return 'Sources';
      default:
        return '???';
    }
  }

  List<View> _renderAddressViews(
      AddressCategory addressCategory, ReadList<Address> addressList, Lifespan lifespan) {
    List<View> addressViews = [];

    for (AddressCategory ac in AddressCategory.values) {
      addressViews.add(_renderAddressCategory(ac, _sectionName(ac), lifespan));
      if (ac == addressCategory) {
        for (Address address in addressList.elements) {
          Operation activateAddress = zone.makeOperation(() {
            if (address.email.value != null) {
              navText.value = address.email.value;
            } else {
              navText.value = '"${address.name}"';
            }
          });
          addressViews.add(_renderAddress(
              address.contextDisplayName, Constant<bool>(false), activateAddress, lifespan));
        }
      }
    }

    return addressViews;
  }

  View renderContextPane(String search, AddressCategory addressCategory, Lifespan lifespan) {
    ReadList<Address> addressList = datastore
        .runQuery(
            ContextQuery(ItemQuery(search, false), addressCategory), lifespan, CONTEXT_PRIORITY)
        .cast<Address>();
    List<View> renderAddressViews = _renderAddressViews(addressCategory, addressList, lifespan);
    MutableList<View> columnViews = BaseMutableList<View>(renderAddressViews);
    Operation updateColumn = zone.makeOperation(
        () => columnViews.replaceWith(_renderAddressViews(addressCategory, addressList, lifespan)));
    addressList.observe(updateColumn, lifespan);
    FlexStyle columnStyle = new FlexStyle(idSource.nextId(), START_MAIN_AXIS, END_CROSS_AXIS);
    return ColumnView(columnViews, Constant<Style>(columnStyle));
  }
}

/*
Widget makePanes() {
  return Column(children: [
    Divider(),
    Expanded(
        child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        renderCategoryColumn(),
        VerticalDivider(),
        Expanded(
            child: ListView(
          padding: const EdgeInsets.all(8.0),
          children: <Widget>[
            Container(
              //height: 50,
              //color: Colors.amber[600],
              child: const Center(child: Text('Entry A')),
            ),
            Divider(),
            Container(
              //height: 50,
              //color: Colors.amber[500],
              child: const Center(child: Text('Entry B')),
            ),
            Divider(),
            Container(
              height: 100,
              color: Colors.amber[100],
              child: const Center(child: Text('Entry C')),
            ),
            new Divider(color: Colors.redAccent[200], height: 1.0),
            Container(
              height: 50,
              color: Colors.amber[600],
              child: const Center(child: Text('Entry A')),
            ),
            Container(
              height: 50,
              color: Colors.amber[500],
              child: const Center(child: Text('Entry B')),
            ),
            Container(
              height: 50,
              color: Colors.amber[100],
              child: const Center(child: Text('Entry C')),
            ),
          ],
        ))
      ],
    ))
  ]);
}
*/
