
RSpec::Matchers.define :have_seen_sql do |sql|
  match do |db|
    db.saw_sql(sql)
  end

  failure_message_for_should do |db|
    "Should have seen...\n#{sql}\n...but instead saw...\n#{db.sqls.join("\n.....\n")}"
  end
end

