import 'package:profiler_blocker/profiler_blocker.dart';

import '../models/profile.dart';

/// Buckets used to suggest apps for each profile and to filter the picker.
/// Matching uses known package names, Android app categories and label
/// keywords, so it also catches regional banks/wallets we didn't list.
enum AppGroup {
  messaging('Messaging'),
  calls('Calls & contacts'),
  banking('Banking & payments'),
  email('Email'),
  social('Social media'),
  video('Video & streaming'),
  games('Games'),
  news('News'),
  shopping('Shopping');

  final String label;
  const AppGroup(this.label);
}

const _packages = <AppGroup, Set<String>>{
  AppGroup.messaging: {
    'com.whatsapp', 'com.whatsapp.w4b', 'com.google.android.apps.messaging',
    'com.samsung.android.messaging', 'com.android.mms', 'org.telegram.messenger',
    'org.thoughtcrime.securesms', 'com.facebook.orca', 'com.discord',
    'com.Slack', 'jp.naver.line.android', 'com.viber.voip', 'com.tencent.mm',
    'com.microsoft.teams', 'com.google.android.apps.dynamite',
  },
  AppGroup.calls: {
    'com.google.android.dialer', 'com.samsung.android.dialer',
    'com.android.dialer', 'com.android.contacts', 'com.samsung.android.contacts',
    'com.google.android.contacts', 'com.skype.raider',
    'us.zoom.videomeetings', 'com.google.android.apps.tachyon',
  },
  AppGroup.banking: {
    'com.chase.sig.android', 'com.wf.wellsfargomobile',
    'com.infonow.bofa', 'com.konylabs.capitalone', 'com.citi.citimobile',
    'com.usaa.mobile.android.usaa', 'com.americanexpress.android.acctsvcs.us',
    'com.discoverfinancial.mobile', 'com.paypal.android.p2pmobile',
    'com.venmo', 'com.squareup.cash', 'com.zellepay.zelle',
    'com.google.android.apps.walletnfcrel',
    'com.google.android.apps.nbu.paisa.user', 'com.phonepe.app',
    'net.one97.paytm', 'in.org.npci.upiapp', 'com.sbi.lotusintouch',
    'com.csam.icici.bank.imobile', 'com.snapwork.hdfc', 'com.axis.mobile',
    'com.robinhood.android', 'com.fidelity.android', 'com.schwab.mobile',
    'com.coinbase.android', 'com.samsung.android.spay',
  },
  AppGroup.email: {
    'com.google.android.gm', 'com.microsoft.office.outlook',
    'com.samsung.android.email.provider', 'com.yahoo.mobile.client.android.mail',
    'ch.protonmail.android',
  },
  AppGroup.social: {
    'com.instagram.android', 'com.instagram.barcelona', 'com.facebook.katana',
    'com.facebook.lite', 'com.zhiliaoapp.musically', 'com.ss.android.ugc.trill',
    'com.twitter.android', 'com.snapchat.android', 'com.reddit.frontpage',
    'com.pinterest', 'com.linkedin.android', 'com.tumblr',
    'com.bereal.ft', 'com.quora.android', 'xyz.blueskyweb.app',
  },
  AppGroup.video: {
    'com.google.android.youtube', 'com.netflix.mediaclient',
    'com.amazon.avod.thirdpartyclient', 'com.disney.disneyplus',
    'tv.twitch.android.app', 'com.hulu.plus', 'com.wbd.stream',
  },
  AppGroup.news: {
    'com.google.android.apps.magazines', 'flipboard.app', 'com.nytimes.android',
    'com.cnn.mobile.android.phone',
  },
  AppGroup.shopping: {
    'com.amazon.mShop.android.shopping', 'com.ebay.mobile',
    'com.einnovation.temu', 'com.zzkko', 'com.walmart.android',
    'in.amazon.mShop.android.shopping', 'com.flipkart.android',
  },
  AppGroup.games: {},
};

const _keywords = <AppGroup, List<String>>{
  AppGroup.messaging: ['messag', 'messenger', 'sms', 'whatsapp', 'telegram'],
  AppGroup.calls: ['dialer', 'phone', 'contacts', 'facetime'],
  AppGroup.banking: [
    'bank', 'wallet', ' pay', 'pay ', 'upi', 'credit union', 'credit card',
    'invest', 'trading', 'crypto',
  ],
  AppGroup.email: ['mail', 'outlook'],
  AppGroup.social: ['tiktok', 'instagram', 'facebook', 'snapchat', 'threads'],
  AppGroup.video: [' tv ', 'stream', 'video'],
  AppGroup.news: ['news'],
  AppGroup.shopping: [' shop', 'shopping'],
  AppGroup.games: [],
};

// android.content.pm.ApplicationInfo.CATEGORY_*
const _catGame = 0, _catVideo = 2, _catSocial = 4, _catNews = 5;

Set<AppGroup> groupsOf(InstalledApp app) {
  final out = <AppGroup>{};
  final label = ' ${app.label.toLowerCase()} ';
  for (final g in AppGroup.values) {
    if (_packages[g]!.contains(app.packageName)) {
      out.add(g);
      continue;
    }
    for (final k in _keywords[g]!) {
      if (label.contains(k)) {
        out.add(g);
        break;
      }
    }
  }
  switch (app.category) {
    case _catGame:
      out.add(AppGroup.games);
    case _catVideo:
      out.add(AppGroup.video);
    case _catSocial:
      out.add(AppGroup.social);
    case _catNews:
      out.add(AppGroup.news);
  }
  return out;
}

Set<AppGroup> defaultGroupsFor(ProfileKind kind) => switch (kind) {
      ProfileKind.kid => {
          AppGroup.messaging,
          AppGroup.calls,
          AppGroup.banking,
          AppGroup.email,
          AppGroup.shopping,
        },
      ProfileKind.focus => {AppGroup.social},
      ProfileKind.work => {
          AppGroup.social,
          AppGroup.video,
          AppGroup.games,
          AppGroup.news,
          AppGroup.shopping,
        },
      ProfileKind.custom => <AppGroup>{},
    };

Set<String> suggestPackages(Set<AppGroup> groups, List<InstalledApp> apps) => {
      for (final a in apps)
        if (groupsOf(a).any(groups.contains)) a.packageName,
    };
