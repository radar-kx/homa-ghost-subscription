# Sources and research notes

Homa Ghost 2 was implemented from scratch. The sources below were used to verify Marzban compatibility, current client availability, import URL formats, and useful subscription-page interaction patterns.

## Marzban

- Official custom subscription template guide: https://gozargah.github.io/marzban/en/docs/subscription
- Official repository: https://github.com/Gozargah/Marzban
- Subscription router and supported client-format routes: https://github.com/Gozargah/Marzban/blob/master/app/routers/subscription.py
- User response fields: https://github.com/Gozargah/Marzban/blob/master/app/models/user.py
- Default subscription page: https://github.com/Gozargah/Marzban/blob/master/app/templates/subscription/index.html

## Subscription-template survey

- QoQnoos: https://github.com/rezazoom/qoqnoos-template
- marz-sub-page: https://github.com/metgen/marz-sub-page
- samimifar/marzban-template: https://github.com/samimifar/marzban-template
- x0sina/marzban-sub: https://github.com/x0sina/marzban-sub
- MuhammadAshouri/marzban-templates: https://github.com/MuhammadAshouri/marzban-templates
- WhyMan/marzban-template: https://github.com/WhyMan1/marzban-template

The survey informed the feature set: responsive cards, status and quota summaries, QR import, quick-add actions, client-specific guides, multilingual-friendly layout decisions, and configuration-copy tools. No third-party template source code is bundled.

## Client download and documentation links

- Hiddify: https://github.com/hiddify/hiddify-app/releases
- v2rayNG: https://github.com/2dust/v2rayNG/releases
- v2rayN: https://github.com/2dust/v2rayN/releases
- Clash Verge Rev: https://github.com/clash-verge-rev/clash-verge-rev/releases
- Streisand: https://apps.apple.com/us/app/streisand/id6450534064
- V2Box Android: https://play.google.com/store/apps/details?id=dev.hexasoftware.v2box
- V2Box iOS / iPadOS: https://apps.apple.com/us/app/v2box-v2ray-client/id6446814690
- V2Box subscription setup: https://hiddify.com/manager/client-software-on-ios/Tutorial-for-V2Box-app/
- Shadowrocket: https://apps.apple.com/us/app/shadowrocket/id932747118
- Happ: https://www.happ.su/main
- v2rayA Linux installation: https://v2raya.org/en/docs/prologue/installation/linux/

## Bundled dependency

`vendor/qrcode.js` is the MIT-licensed QR Code Generator for JavaScript by Kazuhiko Arase. See `THIRD_PARTY_NOTICES.md` and the license header in the vendored file.
