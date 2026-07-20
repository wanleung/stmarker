# About Author and GitHub Link Design

## Goal

Update Subtitle Marker's About dialog to identify Wan Leung Wong as the author
and provide the GitHub repository as the sole contact route. No email address
will be displayed or stored in the dialog.

## User interface

The existing application name, version, description, GPL notice, technology
summary, and Noto font licence notice remain unchanged. Below the application
description, the dialog will show:

- `Author: Wan Leung Wong`
- a visibly clickable `github.com/wanleung/stmarker` project link

Activating the project link opens `https://github.com/wanleung/stmarker` in the
system's default browser. The link will have an accessible label or tooltip so
its purpose is clear without relying on colour alone.

## Implementation

Add Flutter's `url_launcher` package and keep the repository URI as a constant
beside the About-dialog implementation. The dialog will invoke `launchUrl` in
external-application mode. A launch failure will not close the About dialog or
crash the application; the user will receive a concise SnackBar error.

Keep link launching injectable at the dialog boundary so widget tests can
verify the requested URI without opening a real browser.

## Verification

Widget tests will verify that the author and repository label are displayed,
that no email address is present, and that activating the link requests the
expected HTTPS URI. Existing About-dialog assertions must continue to pass.
Run formatting, Flutter analysis, the full test suite, and a Linux build before
completion.
