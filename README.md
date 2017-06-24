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

You'll also need to obtain and set up a client ID and client secret.

1. Go to the Munzee [Developer Dashboard](https://www.munzee.com/api/apps).
1. Click on 'Create App'.
1. Enter the app details as follows:
    * App Name: `JournalZee`
    * Description: `Generate a list of captures suitable for posting to
      Livejournal or Dreamwidth`
    * Redirect URI: `http://localhost:8558/oauth2/callback`
1. Click on 'Create App'.
1. Take note of the ID and Secret of the newly created app.
1. Create a file named `.journalzee.conf` in your home directory.
1. Add the following lines to this file:

    ```yaml
    client_id: CLIENT_ID
    client_secret: CLIENT_SECRET
    ```

    where CLIENT\_ID and CLIENT\_SECRET are the ID and Secret you noted above.

## Usage

Command line help:

```text
$ ruby journalzee.rb -h
Usage: journalzee.rb [options] [startdate [enddate]]
    -h, -?, --help                   Option help
    -l, --login                      Ignore saved token and force a new login
Recommended format for dates is YYYY-MM-DD, e.g. 2017-06-15.
If no dates are specified, process the most recent weekend.
If only one date is specified, it's a one-day date range.
```

If you run JournalZee without any arguments, i.e.:

```bash
ruby journalzee.rb
```

it produces a list of captures from the most recent weekend.

If you have not authorized this script with Munzee, it will launch the default
browser and take you through the authorization sequence to get an access token.
After the first time, JournalZee saves the access token for subsequent runs so
no further authorization is needed until the token expires. To force JournalZee
to perform this authorization sequence again (e.g. if you want to log in as a
different Munzee user), use the `-l` option:

```bash
ruby journalzee.rb -l
```

To generate a capture list for a range of dates other than the most recent
weekend, specify the start and end dates on the command line. For example:

```bash
ruby journalzee.rb 2017-06-10 2017-06-15
```

I recommend using the YYYY-mm-dd format for dates.

To generate a capture list for one day, specify just that date. For example:

```bash
ruby journalzee.rb 2017-06-15
```

