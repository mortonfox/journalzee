# JournalZee

## Introduction

JournalZee generates a list of Munzee captures from the weekend (or any date
range) suitable for inserting into a Livejournal or Dreamwidth post.

## Setup

JournalZee requires the [Launchy](https://github.com/copiousfreetime/launchy)
and [oauth2](https://github.com/intridea/oauth2) gems. If these gems are not
yet installed, you'll need to run the following:

```bash
gem install launchy oauth2
```

## Usage

Command line help:

```
$ ruby journalzee.rb -h
Usage: journalzee.rb [options] [startdate [enddate]]
    -h, -?, --help                   Option help
    -l, --login                      Ignore saved token and force a new login
Recommended format for dates is YYYY-MM-DD, e.g. 2017-06-15.
If no dates are specified, process the most recent weekend.
If only one date is specified, it's a one-day date range.
$
```

If you run JournalZee without any arguments, i.e.:

```
ruby journalzee.rb
```

it produces a list of captures from the most recent weekend.

If you have not authorized this script with Munzee, it will launch the default
browser and take you through the authorization sequence to get an access token.
After the first time, JournalZee saves the access token for subsequent runs so
no further authorization is needed until the token expires. To force JournalZee
to perform this authorization sequence again (e.g. if you want to log in as a
different Munzee user), use the `-l` option:

```
ruby journalzee.rb -l
```

To generate a capture list for a range of dates other than the most recent
weekend, specify the start and end dates on the command line. For example:

```
ruby journalzee.rb 2017-06-10 2017-06-15
```

I recommend using the YYYY-mm-dd format for dates.

To generate a capture list for one day, specify just that date. For example:

```
ruby journalzee.rb 2017-06-15
```

