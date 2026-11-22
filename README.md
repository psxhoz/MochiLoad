# MochiLoad

MochiLoad installs and refreshes sideloaded apps on iPhone with a free Apple ID, without a computer after setup. It's built to be easy for people who have never sideloaded before.

## Download

The newest build is on the [latest-build release](https://github.com/psxhoz/MochiLoad/releases/tag/latest-build) as `MochiLoad.ipa`. GitHub Actions builds it automatically every time `main` changes.

## First-time setup (once per phone)

1. On a computer, sideload `MochiLoad.ipa` once (for example with [iloader](https://github.com/nab138/iloader) or Sideloadly) and make a pairing file for the iPhone.
2. On the iPhone, install **LocalDevVPN** from the App Store and turn it on.
3. Open MochiLoad, import the pairing file when it asks, sign in with your Apple ID, and turn on auto-refresh.

## Apps in Browse

Browse shows the apps listed in [`source.json`](source.json). Add an app there and it shows up for everyone using MochiLoad.

## Building it yourself

You need macOS with Xcode. Clone with submodules, then run:

```sh
git clone --recurse-submodules https://github.com/psxhoz/MochiLoad.git
cd MochiLoad
make build fakesign ipa
```

The result is `SideStore.ipa`, which the build workflow renames to `MochiLoad.ipa`.

## Credits

MochiLoad is a modified version of [SideStore](https://github.com/SideStore/SideStore), which is itself a fork of [AltStore](https://github.com/altstoreio/AltStore) by Riley Testut. Thank you to the SideStore and AltStore teams and everyone who works on them, including the authors of [em_proxy](https://github.com/jkcoxson/em_proxy), [minimuxer](https://github.com/SideStore/minimuxer), [LocalDevVPN](https://github.com/jkcoxson/LocalDevVPN) and [Jitterbug](https://github.com/osy/Jitterbug).

This repository started from SideStore at upstream commit `4f3d18d`. MochiLoad is an independent project and is not affiliated with or supported by the SideStore or AltStore teams, so please don't send MochiLoad questions to them.

## License

MochiLoad is licensed under the **AGPLv3**, the same as SideStore. See [LICENSE](LICENSE). If you share MochiLoad with anyone, this source code has to stay available to them.
