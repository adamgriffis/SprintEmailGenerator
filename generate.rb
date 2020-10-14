require 'clubhouse2'
require 'YAML'
require "csv"

class Generator
  API_KEY = 'API_KEY'
  YEAR = '2020'
  PLANNED_ROADMAP_LABEL_NAME = "planned"
  UNPLANNED_ROADMAP_LABEL_NAME = "unplanned"
  TECHNICAL_DEBT_LABEL_NAME = "Tech Debt"
  REACT_REFACTOR_LABEL_NAME = "React Refactor"

  LABEL_MAJOR_NAME = "major"
  LABEL_CRITICAL_NAME = "critical"
  LABEL_REGRESSION_NAME = "regression"

  NON_PRODUCT_LABEL_NAME = 'Non-product'
  ACCOUNT_CUSTOMIZATION_LABEL_NAME = 'Account Customization'
  STORY_TYPE_BUG = 'bug'
  STORY_TYPE_CHORE = 'chore'
  IN_QA_NAME = 'In QA'
  COMPLETED_NAME = 'Completed'  
  HAS_STORY_NAME = 'has story'
  SPRINT_COMMITTED_LABEL_NAME = 'Sprint Committed'


  def api_key
    config = YAML::load(File.open('config/application.yml'))

    config[API_KEY]
  end

  def point_string(story)
    if story.story_type == STORY_TYPE_BUG 
      return '-'
    else
      return story.estimate
    end
  end

  def story_stats(stories)
    num_stories = 0
    points = 0

    stories.each do |story|
      num_stories += 1
      points += (story.estimate || 0)
    end

    return num_stories, points
  end

  def issue_type(story)
    if story.story_type == STORY_TYPE_CHORE
      if story.labels.map(&:name).include? ACCOUNT_CUSTOMIZATION_LABEL_NAME
        return "Account Customization"
      end

      return "Chore"
    elsif story.story_type == STORY_TYPE_BUG
      return "Bug"
    else

      if story.labels.map(&:name).include? NON_PRODUCT_LABEL_NAME
        return "Non-product Story"
      elsif story.labels.map(&:name).include? PLANNED_ROADMAP_LABEL_NAME
        return "Planned Roadmap Story"
      elsif story.labels.map(&:name).include? UNPLANNED_ROADMAP_LABEL_NAME
        return "Unplanned Roadmap Story"
      elsif story.labels.map(&:name).include? TECHNICAL_DEBT_LABEL_NAME
        return "Technical Debt Story"
      elsif story.labels.map(&:name).include? REACT_REFACTOR_LABEL_NAME
        return "React Refactor Story"
      else
        return "Unknown Story -- please label"
      end
    end
  end

  def generate_table_body(stories, sprint_committed_label)
    result = ''

    stories.sort_by {|story| story.estimate || 0 }.reverse.each do |story|
      result += <<-HTML
        <tr>
          <td>CH-#{story.id}#{story.labels.include?(sprint_committed_label) ? "<br/><b>Sprint Committed</b>" : ""}</td>
          <td>#{issue_type(story)}</td>
          <td>#{story.name}</td>
          <td>#{point_string(story)}</td>
        </tr>
      HTML
    end

    return result
  end

  def generate_table(stories, sprint_committed_label)


    result = <<-HTML
      <table class="table table-striped table-bordered table-sm text-left issues">
        <thead>
          <tr> 
            <th width="10%">
              Issue<br/> 
              Number
            </th>
            <th width="15%">
              Issue<br/>
              Type
            </th>
            <th width="50%">
              Name
            </th>
            <th width="10%">
              Points
            </th>
          </tr>
        </thead>
        <tbody>
          #{generate_table_body(stories, sprint_committed_label)}
        </tbody>
      </table>
    HTML
  end

  def bugs_created_this_sprint(bugs)
    sprint_start = Date.today - 15

    bugs.filter { |bug| bug.created_at > sprint_start }
  end

  def bug_stats(bugs)
    count_regression = 0
    count_major = 0 
    count_critical = 0

    bugs.each do |bug|
      count_regression += 1 if bug.labels.map(&:name).include? LABEL_REGRESSION_NAME
      count_major += 1 if bug.labels.map(&:name).include? LABEL_MAJOR_NAME
      count_critical += 1 if bug.labels.map(&:name).include? LABEL_CRITICAL_NAME
    end

    return count_regression, count_major, count_critical
  end

  def has_story_stats(client)
    has_story_label = client.label(name: HAS_STORY_NAME) 
    in_qa_state = client.workflow.state(name: IN_QA_NAME)
    completed_state = client.workflow.state(name: COMPLETED_NAME)
    in_progress_state_ids = client.workflow.states.reject { |state| state == in_qa_state || state == completed_state }.map(&:id)

    stories = client.stories(archived: false, labels: has_story_label, completed: false)

    working_state_ids = [completed_state, in_qa_state] + in_progress_state_ids

    stories = stories.select { |story| !in_progress_state_ids.include?(story.workflow_state_id) }

    story_stats(stories)
  end

  def create_sprint_stats_csv(sprint, velocity, num_stories_planned, num_stories_unplanned, num_stories_tech_debt, num_stories_nonproduct, num_bugs_completed, num_bugs_created,
      points_planned, points_unplanned, points_tech_debt, points_nonproduct, points_customization, num_stories_customization, points_not_completed, num_not_completed, percent_completed_of_committed, 
      points_has_story, num_has_story)

    CSV.open("sprints/stats.csv", "wb",
      write_headers: true,
      headers: ["sprint",
        "velocity", 
        "points planned", 
        "points unplanned", 
        "points tech debt",
        "points non product",
        "points customization",
        "num planned",
        "num unplanned",
        "num tech debt", 
        "num non product",
        "num bugs completed",
        "num bugs created",
        "points not completed",
        "num_not_completed",
        "percent completed of committed",
        "points have story",
        "num have story"]) do |csv|

        csv << [
          sprint,
          velocity,
          points_planned,
          points_unplanned,
          points_tech_debt,
          points_nonproduct,
          points_customization,
          num_stories_planned,
          num_stories_unplanned,
          num_stories_tech_debt,
          num_stories_nonproduct,
          num_bugs_completed,
          num_bugs_created,
          points_not_completed,
          num_not_completed,
          percent_completed_of_committed,
          points_has_story,
          num_has_story
        ]
    end
  end



  def create_bug_stats_csv(sprint, num_bugs_created, num_bugs_completed, num_regression_created, num_regression_completed, num_major_created, num_major_completed, num_critical_created, num_critical_completed)
    CSV.open("sprints/bugs.csv", "wb",
      write_headers: true,
      headers: ["sprint", 
        "num created",
        "num completed",
        "num regression created",
        "num regression completed",
        "num major created", 
        "num major completed",
        "num critical created",
        "num critical completed"]) do |csv|
        
        csv << [
          sprint,
          num_bugs_created,
          num_bugs_completed,
          num_regression_created,
          num_regression_completed,
          num_major_created,
          num_major_completed,
          num_critical_created,
          num_critical_completed
        ]
    end
  end

  def generate_email(sprint_name)
    client = Clubhouse::Client.new(api_key: api_key)
    sprint_label  = client.label(name: sprint_name)
    planned_rm_label = client.label(name: PLANNED_ROADMAP_LABEL_NAME)
    unplanned_rm_label = client.label(name: UNPLANNED_ROADMAP_LABEL_NAME)
    technical_debt_rm_label = client.label(name: TECHNICAL_DEBT_LABEL_NAME)
    non_product_label = client.label(name: NON_PRODUCT_LABEL_NAME)
    account_customization_label = client.label(name: ACCOUNT_CUSTOMIZATION_LABEL_NAME)
    sprint_committed_label = client.label(name: SPRINT_COMMITTED_LABEL_NAME)

    stories = client.stories(archived: false, labels: sprint_label)

    points_completed = sprint_label.stats["num_points_completed"]
    stories_completed = sprint_label.stats["num_stories_completed"]

    in_qa_state = client.workflow.state(name: IN_QA_NAME)
    completed_state = client.workflow.state(name: COMPLETED_NAME)
    in_progress_state_ids = client.workflow.states.reject { |state| state == in_qa_state || state == completed_state }.map(&:id)

    num_stories_completed = sprint_label.stats['num_stories_completed']
    points_completed = sprint_label.stats['num_points_completed']

    bugs_in_sprint = sprint_label.stories.select { |story| story.story_type == STORY_TYPE_BUG }
    bugs_created_this_sprint = bugs_created_this_sprint(bugs_in_sprint)
    completed_stories = sprint_label.stories.select {|story| story.workflow_state_id == completed_state.id}
    in_qa_stories = sprint_label.stories.select {|story| story.workflow_state_id == in_qa_state.id}
    in_progress_stories = stories.select {|story| in_progress_state_ids.include?(story.workflow_state_id) }

    completed_non_product_stories = completed_stories.select {|story| story.labels.include?(non_product_label) && story.story_type != STORY_TYPE_BUG }
    completed_planned_stories = completed_stories.select {|story| story.labels.include?(planned_rm_label) && story.story_type != STORY_TYPE_BUG }
    completed_unplanned_stories = completed_stories.select {|story| story.labels.include?(unplanned_rm_label) && story.story_type != STORY_TYPE_BUG }
    completed_tech_debt_stories = completed_stories.select {|story| story.labels.include?(technical_debt_rm_label) && story.story_type != STORY_TYPE_BUG }
    completed_account_customization = completed_stories.select { |story| story.labels.include?(account_customization_label) && story.story_type == STORY_TYPE_CHORE }
    completed_bugs = completed_stories.select {|story| story.story_type == STORY_TYPE_BUG }

    sprint_committed_stories = sprint_label.stories.select {|story| story.workflow_state_id != completed_state.id && story.labels.include?(sprint_committed_label) }

    num_stories_customization, points_customization = story_stats(completed_account_customization)
    num_stories_nonproduct, points_nonproduct = story_stats(completed_non_product_stories)
    num_stories_unplanned, points_unplanned = story_stats(completed_unplanned_stories)
    num_stories_planned, points_planned = story_stats(completed_planned_stories)
    num_stories_tech_debt, points_tech_debt = story_stats(completed_tech_debt_stories)
    num_bugs, points_bugs = story_stats(completed_bugs)
    num_stories_qa, points_qa = story_stats(in_qa_stories)
    num_stories_in_progress, points_in_progress = story_stats(in_progress_stories)
    num_has_story, points_has_story = has_story_stats(client)
    num_sprint_comitted, points_sprint_committed = story_stats(sprint_committed_stories)

    num_bugs_created = bugs_created_this_sprint.length
    num_regression_created, num_major_created, num_critical_created = bug_stats(bugs_created_this_sprint)
    num_regression_completed, num_major_completed, num_critical_completed = bug_stats(bugs_created_this_sprint)

    points_completed -= points_customization

    percent_unplanned = points_unplanned / points_completed.to_f * 100
    percent_planned = points_planned / points_completed.to_f * 100
    percent_nonproduct = points_nonproduct / points_completed.to_f * 100
    percent_tech_debt = points_tech_debt / points_completed.to_f * 100
    percent_planned_of_rm = points_planned / (points_unplanned + points_planned).to_f * 100
    percent_completed_of_committed = (points_completed) / (points_completed + points_sprint_committed).to_f * 100 

    create_sprint_stats_csv(sprint_name, points_completed, num_stories_planned, num_stories_unplanned, num_stories_tech_debt, num_stories_nonproduct, num_bugs, num_bugs_created, points_planned, points_unplanned, points_tech_debt, points_nonproduct,
      points_customization, num_stories_customization, points_sprint_committed, num_sprint_comitted, percent_completed_of_committed, points_has_story, num_has_story)

    create_bug_stats_csv(sprint_name, num_bugs_created, num_bugs, num_regression_created, num_regression_completed, num_major_created, num_major_completed, num_critical_created, num_critical_completed)

    result = <<-HTML
    <html>
      <head>
        <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css" integrity="sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO" crossorigin="anonymous">
        <style type="text/css">
          table.issues{
            width: 60%;
          }
        </style>
      </head>
      <body>
        <p>This sprint our velocity was [up/down/the same]: #{points_completed} points ([up/down from X] last sprint).</p>

        <h5>Story breakdown stats:</h5>
        <p>
          <ul>
            <li><strong>Number Planned Stories vs Unplanned Stories vs Tech Debt vs Non-product vs Bugs:</strong> #{num_stories_planned} vs #{num_stories_unplanned} vs #{num_stories_tech_debt} vs #{num_stories_nonproduct} vs #{num_bugs}</li>
            <li><strong>Planed vs Unplanned vs Tech Debt vs Non-Product Points:</strong> #{points_planned} (#{"%.1f" % percent_planned}%) vs #{points_unplanned} (#{"%.1f" % percent_unplanned}%) vs #{points_tech_debt} (#{"%.1f" % points_tech_debt}) vs #{points_nonproduct} (#{"%.1f" % percent_nonproduct}%)</li>
            <li><strong>Points spent on account customization (not currently included in velocity):</strong> #{points_customization} (#{num_stories_customization} storie(s))
            <li><strong>Points we committed to but didn't finish:</strong> #{points_sprint_committed} (#{num_sprint_comitted} storie(s)) --- #{"%.1f" % percent_completed_of_committed}% of commitments completed</li>
            <li><strong>Percent roadmap planned: #{percent_planned_of_rm}

            <li><strong>"Storied" backlog:</strong> #{points_has_story} (#{num_has_story} storie(s))</li>           
          </ul>
        </p>
        <h5>Bug stats:</h5>
        <p>
          <ul>
            <li><strong>Bugs Created vs Bugs Fixed:</strong>#{num_bugs_created} vs #{num_bugs}</li>
            <li><strong>Bugs Created Regression, Major and Critical:</strong>#{num_regression_created} regression, #{num_major_created} major, #{num_critical_created} critical</li>
            <li><strong>Bugs Completed Regression, Major and Critical:</strong>#{num_regression_completed} regression, #{num_major_completed} major, #{num_critical_completed} critical</li>

            <li><strong>"Storied" backlog:</strong> #{points_has_story} (#{num_has_story} storie(s))</li>            
          </ul>
        </p>

        <h5>Heroes:</h5>
        <p>
        </p>

        <h5>Hassles:</h5>
        <p>
        </p>

        <h5>Completed (#{points_completed}):</h5>
        #{generate_table(completed_stories, sprint_committed_label)}

        <h5>In QA (#{points_qa}):</h5>
        #{generate_table(in_qa_stories, sprint_committed_label)}    

        <h5>In Progress (#{points_in_progress}):</h5>
        #{generate_table(in_progress_stories, sprint_committed_label)}
      </body>
    </html>

    HTML
  end
end

sprint = ARGV[0..10].join(' ')
puts "Sprint #{sprint}"
generator = Generator.new
path = "sprints/sprint-#{sprint.downcase.gsub(" ", "-")}.html"
html = generator.generate_email(sprint)
File.open(path, 'w') { |file| file.write(html) }
system %{open "#{path}"}
system %{open "sprints/stats.csv"}
system %{open "sprints/bugs.csv"}
puts "======================================================================================"
puts "=                      Done Generating HTML                                          ="
puts "======================================================================================"