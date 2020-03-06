// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum ApplicationConfig {
  BRIEFING_GMAIL,
  BRIEFING_HACKER_NEWS_PREPARED,
  BRIEFING_HACKER_NEWS_LIVE,
  COUNTER,
  CREATE_LEGACY,
  CREATE_RESET,
  CREATE_FIRESTORE,
  CREATE_DEMO,
  PAINT,
  SLIDER
}

//const ApplicationConfig APPLICATION = ApplicationConfig.BRIEFING_HACKER_NEWS_PREPARED;
const ApplicationConfig APPLICATION = ApplicationConfig.CREATE_DEMO;
//const ApplicationConfig APPLICATION = ApplicationConfig.COUNTER;

// Prefix used for categories in the Briefing app
const String HASH_PREFIX = '#';

// Maximum number of items to display in the Briefing app
const int MAX_ITEMS = 50;

// Maximum number of context items in the Briefing app
const int MAX_CONTEXT_ITEMS = 20;

// Maximum number of concurrent requests in the Briefing app
const int MAX_CONCURRENT_REQUESTS = 12;

// Specifies whether to log Firestore sync requests
const bool LOG_SYNC_REQUESTS = true;

// Specifies whether to log request information in the Briefing app
const bool LOG_REQUESTS = false;

// Create app version, identifies the datastore with which it syncs
const String CREATE_VERSION = 'DEV';
