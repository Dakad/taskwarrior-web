## v0.0.5 (6/5/11)

* Added "depends" method to task model so that tasks that use depends will not
  throw errors.

## v0.0.4 (5/9/11)

* Quick bugfix to remove checkboxes from project page. Race conditions prevent
  the IDs from actually being correct, so the wrong task would be marked as
  done.

## v0.0.3 (5/9/11)

* Fixed floating issue in FF4 on /projects page
* Added "priority" to list of attributes (no more errors)
* Added sorting by priority first
* Added column for priority to all listings
