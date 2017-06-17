# ReportZee

## Introduction

The purpose of this script is to generate a report of the weekend's Munzee
captures for inserting into a Livejournal or Dreamwidth post.

## Setup

reportzee requires the [Oga](https://github.com/YorickPeterse/oga) gem. So if
that is not yet installed, you'll need to run the following:

    gem install oga

## Usage

First you'll need to save the "One Day In Your Munzee Life" web pages.

* Visit your Munzee profile.
* Under the heading "Recent Activity", you'll see a strip with one green,
  orange, or orange/green block per day of activity. Find the days for which
  you want a report. Right-click and save those links to files.

Pass those files as command line arguments to reportzee. For example:

    ruby reportzee.rb day20170610.htm day20170611.htm

The script will work on those files and output HTML code that you can insert
into a Livejournal post.
