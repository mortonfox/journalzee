require 'oga'
require 'date'

def parse_file io
  doc = Oga.parse_html(io)

  result = {}

  datestr = doc.at_css('.page-header span small').text.strip
  result[:date] = Date.parse(datestr)

  # First stats table is for captures.
  result[:captures] = doc.at_css('#stats-table tbody').css('tr').map { |tr_elem|
    cells = tr_elem.css('td')

    link_elem = cells[1].at_css('a')
    next unless link_elem

    url = link_elem.get('href')
    name = link_elem.text.strip

    owner = cells[2].text.strip

    {
      url: url,
      name: name,
      owner: owner
    }
  }.compact

  result
end

def output_munzees results
  puts <<-EOM
<lj-cut text="The munzees...">
<div style="margin: 10px 30px; border: 1px dashed; padding: 10px;">
  EOM

  results.sort_by { |item| item[:date] }.each { |result|
    puts <<-EOM

#{result[:date].strftime '%A %Y-%m-%d'}:

    EOM

    result[:captures].each { |cap|
      puts <<-EOM
<a href="#{cap[:url]}">#{cap[:name]}</a> #{cap[:owner]}
      EOM
    }
  }

  puts <<-EOM
</div>
</lj-cut>
  EOM
end

results = ARGV.map { |infile|
  open(infile, 'r') { |io|
    parse_file(io)
  }
}

output_munzees(results)

__END__
