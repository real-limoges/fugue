# xmerl ships with OTP but is not a runtime dependency; the feed test parses
# with it, so load it for the test run only.
Mix.ensure_application!(:xmerl)

ExUnit.start()
