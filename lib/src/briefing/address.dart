// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:googleapis/gmail/v1.dart';

import '../../elements.dart';
import 'briefingdata.dart';

class AddressSet {
  final Map<String, Address> _addressByEmail = LinkedHashMap<String, Address>();
  final Map<String, Address> _addressByName = LinkedHashMap<String, Address>();

  Address add(Address address) {
    Address result;

    if (address.email.value != null) {
      result = _addressByEmail[address.email.value];
      if (result != null) {
        if (address.isExplicitName.value) {
          result.name.value = address.name.value;
          result.shortName.value = address.shortName.value;
          result.isExplicitName.value = true;
        }
      } else {
        result = address;
        _addressByEmail[address.email.value] = result;
      }
    } else {
      result = _addressByName[address.name.value];
      if (result != null) {
        if (address.isExplicitName.value) {
          result.name.value = address.name.value;
          result.shortName.value = address.shortName.value;
          result.isExplicitName.value = true;
        }
      } else {
        result = address;
      }
    }

    if (result.isExplicitName.value) {
      _addressByName[result.name.value] = result;
    }

    return result;
  }

  List<Address> all() {
    List<Address> result = List<Address>.from(_addressByEmail.values);

    for (Address address in _addressByName.values) {
      if (address.email.value == null) {
        result.add(address);
        print('Unknown email: $address');
      }
    }

    return result;
  }
}

class AddressHandler {
  final Ref<String> _myEmail;
  final DataIdSource _idSource;
  final AddressSet _allAddresses = AddressSet();

  AddressHandler(this._myEmail, this._idSource);

  void prepareAddresses(List<Message> messages, List<String> parseHeaders) {
    for (String field in getAddressFields(messages, parseHeaders)) {
      parseAddress(field, null);
    }
  }

  List<Address> parseAddresses(List<Message> messages, List<String> parseHeaders) {
    AddressSet addresses = AddressSet();

    for (String field in getAddressFields(messages, parseHeaders)) {
      parseAddress(field, addresses);
    }

    return addresses.all();
  }

  Set<String> getAddressFields(List<Message> messages, List<String> parseHeaders) {
    Set<String> fields = LinkedHashSet<String>();

    for (Message message in messages) {
      List<MessagePartHeader> headers = message.payload.headers;
      for (MessagePartHeader header in headers) {
        if (parseHeaders.contains(header.name)) {
          for (String addressField in splitAddressHeader(header.value)) {
            String trimmedField = addressField.trim();
            if (!isEmptyString(trimmedField)) {
              fields.add(trimmedField);
            }
          }
        }
      }
    }

    return fields;
  }

  List<String> splitAddressHeader(String header) {
    List<String> result = <String>[];

    bool isQuoted = false;
    int startIndex = 0;
    int index;

    for (index = 0; index < header.length; ++index) {
      String c = header.substring(index, index + 1);
      if (c == '"') {
        isQuoted = !isQuoted;
      } else if (c == ',') {
        if (!isQuoted) {
          result.add(header.substring(startIndex, index));
          startIndex = index + 1;
        }
      }
    }
    result.add(header.substring(startIndex));

    return result;
  }

  Address parseAddress(String fullAddress, AddressSet addresses) {
    fullAddress = fullAddress.trim();

    String email;
    String name;
    String shortName;

    int open = fullAddress.indexOf('<');
    if (open < 0) {
      email = normalizeEmail(fullAddress);
    } else {
      name = fullAddress.substring(0, open).trim().replaceAll('"', '');
      email = normalizeEmail(
          fullAddress.substring(open).trim().replaceAll('<', '').replaceAll('>', ''));
    }

    bool isExplicitName = !isEmptyString(name);
    if (isExplicitName) {
      int space = name.indexOf(' ');
      shortName = space >= 0 ? name.substring(0, space) : name;
    } else {
      name = email;
      int at = email.indexOf('@');
      shortName = at >= 0 ? email.substring(0, at + 1) : email;
    }

    if (email == _myEmail.value) {
      shortName = 'me';
    }

    Address address = Address(_idSource.nextId(), email, name, shortName, isExplicitName);
    address = _allAddresses.add(address);

    if (addresses != null) {
      address = addresses.add(address);
    }

    return address;
  }
}
