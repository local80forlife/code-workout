class ExercisesController < ApplicationController
  load_and_authorize_resource


  #~ Action methods ...........................................................

  # -------------------------------------------------------------
  # GET /exercises
  def index
  end


  # -------------------------------------------------------------
  # GET /exercises/download.csv
  def download
    @exercises = Exercise.accessible_by(current_ability)

    respond_to do |format|
      format.csv
      format.json do
        render text:
          ExerciseRepresenter.for_collection.new(@exercises).to_hash.to_json
      end
      format.yml do
        render text:
          ExerciseRepresenter.for_collection.new(@exercises).to_hash.to_yaml
      end
    end
  end


  # -------------------------------------------------------------
  def search
    @terms = escape_javascript(params[:search])
    @terms = @terms.split(@terms.include?(',') ? /\s*,\s*/ : nil)
#    @wos = Workout.search @terms
    @wos = []
    @exs = Exercise.search(@terms, current_user)
    @msg = ''
#    if @wos.length == 0 && @exs.length == 0
    if @exs.length == 0
      @msg = 'No exercises were found for your search request. ' \
        'Try these instead...'
#      @wos = Workout.order('RANDOM()').limit(4)
      @exs = Exercise.order('RANDOM()').limit(16)
    end
    if @exs.length == 0
      @msg = 'No public exercises are available to search right now. ' \
        'Wait for contributors to add more.'
    end
  end


  # -------------------------------------------------------------
  # GET /exercises/1
  def show
  end


  # -------------------------------------------------------------
  # GET /exercises/new
  def new
    @exercise = Exercise.new
    @coding_exercise = CodingQuestion.new
    @languages = Tag.where(tagtype: Tag.language).pluck(:tag_name)
    @areas = Tag.where(tagtype: Tag.area).pluck(:tag_name)
  end


  # -------------------------------------------------------------
  # GET /exercises/1/edit
  def edit
  end


  # -------------------------------------------------------------
  # POST /exercises
  def create
    basex=BaseExercise.new
    ex=Exercise.new
    msg = params[:exercise] || params[:coding_question]
    basex.user_id = current_user.id
    basex.question_type = msg[:question_type] || 1
    basex.versions = 1
    ex.name = msg[:name].chomp.strip
    # ex.question = ERB::Util.html_escape(msg[:question])
    # ex.feedback = ERB::Util.html_escape(msg[:feedback])
    ex.question = msg[:question]
    ex.feedback = msg[:feedback]
    ex.creator_id = current_user.id
    ex.is_public = true
    if msg[:is_public] == 0
      ex.is_public = false
    end

    if msg[:mcq_allow_multiple].nil?
      ex.mcq_allow_multiple = false
    else
      ex.mcq_allow_multiple = msg[:mcq_allow_multiple]
    end

    if msg[:mcq_is_scrambled].nil?
      ex.mcq_is_scrambled = false
    else
      ex.mcq_is_scrambled = msg[:mcq_is_scrambled]
    end
    ex.priority = 0
    # TODO: Get the count of attempts from the session
    ex.count_attempts = 0
    ex.count_correct = 0
    if msg[:language_id]
      ex.language_id = msg[:language_id].to_i
    end

    if msg[:experience]
      ex.experience = msg[:experience]
    else
      ex.experience = 10
    end

    # default IRT statistics
    ex.difficulty = 0
    ex.discrimination = 0
    ex.version = 1

    # Populate coding question's test case
    if msg[:coding_questions]
      codingquestion = CodingQuestion.new
      codingquestion.class_name =
        msg[:coding_questions][:class_name].chomp.strip
      codingquestion.method_name =
        msg[:coding_questions][:method_name].chomp.strip
      codingquestion.wrapper_code =
        msg[:coding_questions][:wrapper_code].chomp.strip
      codingquestion.test_script =
        msg[:coding_questions][:test_script].chomp.strip
      ex.coding_question = codingquestion
      extests = msg[:coding_questions][:test_script].strip.chomp.split("\n")
      extests.each do |tc|
        test_case = TestCase.new
        # FIXME:
        test_case.test_script = 'NONE for now'
        case_splits = tc.split(',')
        test_case.input = case_splits[0].strip.gsub(';', ',')
        test_case.expected_output = case_splits[1].strip
        test_case.weight = 1.0
        # FIXME:
        test_case.description = case_splits[2] unless case_splits[2].nil?
        test_case.negative_feedback = case_splits[3]
        ex.coding_question.test_cases << test_case
      end
    end

    basex.exercises << ex
    ex.save!
    basex.current_version = ex
    basex.save
    if msg[:coding_questions]
      msg[:tag_ids].delete_if(&:empty?)
      language = msg[:tag_ids][0]
      Dir.chdir('usr/resources') do
        test_end_code = generate_tests(ex.id, language,
          msg[:coding_questions][:class_name].chomp.strip,
          msg[:coding_questions][:method_name].chomp.strip)
        puts 'LANGUAGE', 'LANGUAGE', language, 'LANGUAGE', 'LANGUAGE'
        base_test_file = File.open(
          "#{language}BaseTestFile.#{Exercise.extension_of(language)}",
          'rb').read
        test_base = base_test_file.gsub('baseclassclass',
          msg[:coding_questions][:class_name].chomp.strip)

        if language == 'Java'
          first_input = ex.coding_question.test_cases[0].input
          first_expected_output =
            ex.coding_question.test_cases[0].expected_output
          if first_input == 'true' || first_input == 'false'
            puts 'BOOLEAN TYPE', 'BOOLEAN TYPE'
            input_type = 'boolean'
          elsif first_input.include?('"')
            puts 'STRING TYPE', 'STRING TYPE'
            input_type = 'String'
          elsif first_input.include?("'")
             puts 'CHAR TYPE', 'CHAR TYPE'
             input_type = 'char'
          elsif first_input.to_i.to_s == first_input
             puts 'INT TYPE', 'INT TYPE'
             input_type = 'int'
          elsif first_input.to_f.to_s == first_input
             puts 'FLOAT TYPE', 'FLOAT TYPE'
             input_type = 'float'
          else
             puts 'TYPE ERROR', 'TYPE ERROR'
             input_type = 'ERR'
          end
          if first_expected_output == 'true' ||
            first_expected_output == 'false'
            puts 'BOOLEAN TYPE', 'BOOLEAN TYPE'
            output_type = 'boolean'
          elsif first_expected_output.include?('"')
            puts 'STRING TYPE', 'STRING TYPE'
            output_type = 'String'
          elsif first_expected_output.include?("'")
            puts 'CHAR TYPE', 'CHAR TYPE'
            output_type = 'char'
          elsif first_expected_output.to_i.to_s == first_expected_output
            puts 'INT TYPE', 'INT TYPE'
            output_type = 'int'
          elsif first_expected_output.to_f.to_s == first_expected_output
            puts 'FLOAT TYPE', 'FLOAT TYPE'
            output_type = 'float'
          else
            puts 'TYPE ERROR', 'TYPE ERROR'
            output_type = 'ERR'
          end
          if output_type != 'ERR'
            test_base = test_base.gsub('methodnameemandohtem',
              msg[:coding_questions][:method_name].chomp.strip)
            test_base = test_base.gsub('input_type',input_type)
            test_base = test_base.gsub('output_type',output_type)

            base_runner_file = File.open("JavaBaseTestRunner.java","rb").read
            base_runner_code = base_runner_file.gsub('baseclassclass',
              msg[:coding_questions][:class_name].chomp.strip)
            File.open(msg[:coding_questions][:class_name].chomp.strip +
              'TestRunner.java', "wb") { |f| f.write( base_runner_code ) }
          end # !ERR IF
        end # JAVA IF
        testing_code = test_base.gsub('TTTTT', test_end_code)
        File.open(msg[:coding_questions][:class_name].chomp.strip + 'Test.' +
          Exercise.extension_of(language), 'wb') { |f| f.write(testing_code) }
      end
    end

    i = 0
    right = 0.0
    total = 0.0

    # typed in tags
    if msg[:tags_attributes]
      msg[:tags_attributes].each do |t|
        Tag.tag_this_with(ex, t.second["tag_name"].to_s, Tag.skill)
      end
    end

    # selected tags
    msg[:tag_ids].delete_if(&:empty?)
    puts 'TAG IDS', msg[:tag_ids], 'TAG IDS'
    msg[:tag_ids].each do |tag_name|
      Tag.tag_this_with(ex, tag_name.to_s, Tag.misc)
    end
    if msg[:choices_attributes]
      msg[:choices_attributes].each do |c|
        if c.second["value"] == "1"
          right += 1
        end
        total += 1
      end
      msg[:choices_attributes].each do |c|
        tmp = Choice.create
        tmp.answer = ERB::Util.html_escape(c.second[:answer])
        if( c.second["value"] == "1" )
          tmp.value = 1/right
        else
          tmp.value = 0
        end

        tmp.feedback = ERB::Util.html_escape(c.second[:feedback])
        tmp.order = i
        ex.choices << tmp
        #tmp.exercise << @exercise
        tmp.save!

        i=i+1
      end
    end
    if ex.save!
      redirect_to ex, notice: 'Exercise was successfully created.'
    else
      #render action: 'new'
      redirect_to ex, notice:
        "Exercise was NOT created for #{msg} #{@exercise.errors.messages}"
    end
  end


  # -------------------------------------------------------------
  def random_exercise
    exercise_dump = []
    Exercise.where(is_public: true).each do |exercise|
      if params[:language] ?
        (exercise.language == params[:language]) :
        params[:question_type] ?
        (exercise.question_type == params[:question_type].to_i) :
        true

        exercise_dump << exercise
      end
    end
    redirect_to exercise_practice_path(exercise_dump.sample) and return
  end


  # -------------------------------------------------------------
  # POST exercises/create_mcqs
  def create_mcqs
    basex = BaseExercise.new
    basex.user = current_user
    basex.question_type = msg[:question_type] || 1
    basex.versions = 1
    csvfile = params[:form]
    puts csvfile.fetch(:xmlfile).path
    CSV.foreach(csvfile.fetch(:xmlfile).path) do |question|
      if $INPUT_LINE_NUMBER > 1
        name_ex = question[1]
        # priority_ex=question[2]
        question_ex = question[3][3..-5]

        if !question[15].nil? && question[15].include?('p')
          gradertext_ex = question[15][3..-5]
        else
          gradertext_ex = ''
        end

        if !question[5].nil? &&
          !question[6].nil? &&
          !question[5][3..-5].nil? &&
          !question[6][3..-5].nil?

          ex = Exercise.new
          ex.name = name_ex
          ex.question = question_ex
          ex.feedback = gradertext_ex
          ex.is_public = true
          ex.creator_id = current_user.id
          # if msg[:is_public] == 0
            # ex.is_public = false
          # end

          ex.mcq_allow_multiple = true

          # if msg[:mcq_allow_multiple].nil?
            # ex.mcq_allow_multiple = false
          # end

          ex.mcq_is_scrambled = true
          # if msg[:mcq_is_scrambled].nil?
            # ex.mcq_is_scrambled = false
          # end
          ex.priority = 1
          # TODO: Get the count of attempts from the session
          ex.count_attempts = 5
          ex.count_correct = 1
          ex.user = current_user
          ex.experience = 10

          # default IRT statistics
          ex.difficulty = 0
          ex.discrimination = 0

          ex.version = 1
          basex.exercises << ex
          ex.save!
          basex.current_version = ex
          basex.save

          #   i = 0
          #  right = 0.0
          # total = 0.0
          alphanum = {
            'A' => 1, 'B' => 2, 'C' => 3, 'D' => 4, 'E' => 5,
            'F' => 6, 'G' => 7, 'H' => 8, 'I' => 9, 'J' => 10 }
          choices = []
          choice1 = question[5][3..-5]
          choices << choice1
          choice2 = question[6][3..-5]
          choices << choice2
          if !question[7].nil? && question[7].include?('p')
            choice3 = question[7][3..-5]
            choices << choice3
          end
          if !question[8].nil? && question[8].include?('p')
            choice4 = question[8][3..-5]
            choices << choice4
          end
          if !question[9].nil? && question[9].include?('p')
            choice5 = question[9][3..-5]
            choices << choice5
          end
          if !question[10].nil? && question[10].include?('p')
            choice6 = question[10][3..-5]
            choices << choice6
          end
          if !question[11].nil? && question[11].include?('p')
            choice7 = question[11][3..-5]
            choices << choice7
          end
          if !question[12].nil? && question[12].include?('p')
            choice8 = question[12][3..-5]
            choices << choice8
          end
          if !question[13].nil? && question[13].include?('p')
            choice9 = question[13][3..-5]
            choices << choice9
          end
          if !question[14].nil? && question[14].include?('p')
            choice10 = question[14][3..-5]
            choices << choice10
          end

          if question[5] && question[6] &&
            question[5][3..-5] && question[6][3..-5]
            ex = Exercise.new
            ex.name = name_ex
            ex.question = question_ex
            ex.feedback = gradertext_ex
            ex.is_public = true

            # if msg[:is_public] == 0
            #   ex.is_public = false
            # end

            ex.mcq_allow_multiple = true

            # if msg[:mcq_allow_multiple].nil?
            #   ex.mcq_allow_multiple = false
            # end

            ex.mcq_is_scrambled = true
            # if msg[:mcq_is_scrambled].nil?
            #   ex.mcq_is_scrambled = false
            # end
            ex.priority = 1
            # TODO: Get the count of attempts from the session
            ex.count_attempts = 5
            ex.count_correct = 1

            ex.user = current_user
            ex.experience = 10

            # default IRT statistics
            ex.difficulty = 0
            ex.discrimination = 0
            ex.version = 1
            basex.exercises << ex
            ex.save!
            basex.current_version = ex
            basex.save

            #   i = 0
            #  right = 0.0
            # total = 0.0
            alphanum = {
              'A' => 1, 'B' => 2, 'C' => 3, 'D' => 4, 'E' => 5,
              'F' => 6, 'G' => 7, 'H' => 8, 'I' => 9, 'J' => 10 }
            choices = []
            choice1 = question[5][3..-5]
            choices << choice1
            choice2 = question[6][3..-5]
            choices << choice2
            if question[7] && question[7].include?('p')
              choice3 = question[7][3..-5]
              choices << choice3
            end
            if question[8] && question[8].include?('p')
              choice4 = question[8][3..-5]
              choices << choice4
            end
            if question[9] && question[9].include?('p')
              choice5 = question[9][3..-5]
              choices << choice5
            end
            if question[10] && question[10].include?('p')
              choice6 = question[10][3..-5]
              choices << choice6
            end
            if question[11] && question[11].include?('p')
              choice7 = question[11][3..-5]
              choices << choice7
            end
            if question[12] && question[12].include?('p')
              choice8 = question[12][3..-5]
              choices << choice8
            end
            if question[13] && question[13].include?('p')
              choice9 = question[13][3..-5]
              choices << choice9
            end
            if question[14] && question[14].include?('p')
              choice10 = question[14][3..-5]
              choices << choice10
            end
            cnt = 0
            choices.each do |choiceitem|
              ch = Choice.create
              ch.answer = choiceitem
              cnt += 1
              if alphanum[question[5]] == cnt
                ch.value = 1
              else
                ch.value = -1
              end

              ch.feedback = gradertext_ex
              ch.order = cnt
              ex.choices << ch
              # ch.exercise << @exercise
              ch.save!
            end

          else
            puts 'INVALID Question'
            puts 'INVALID choice', choice1
            puts 'INVALID choice', choice2
          end
        end # IF Valid fields
      end # IF 1
      redirect_to exercises_url, notice: 'Uploaded!'
    end # CSV do
  end# def


  # -------------------------------------------------------------
  # GET exercises/upload_mcqs
  def upload_mcqs
  end


  # -------------------------------------------------------------
  # GET exercises/upload_exercises
  def upload
  end


  # -------------------------------------------------------------
  def upload_yaml
  end


  # -------------------------------------------------------------
  def yaml_create
    @yaml_exers = YAML.load_file(params[:form].fetch(:yamlfile).path)
    @yaml_exers.each do |exercise|
      @ex = Exercise.new
      @ex.name = exercise['name']
      @ex.external_id = exercise['external_id']
      @ex.is_public = exercise['is_public']
      @ex.experience = exercise['experience']
      exercise['language_list'].split(",").each do |lang|
        print "\nLanguage: ", lang
      end
      exercise['style_list'].split(",").each do |style|
        print "\nStyle: ", style
      end
      exercise['tag_list'].split(",").each do |tag|
        print "\nTag: ", tag
      end
      version = exercise['current_version']
      @ex.versions = version['version']
      @ex.save!
      @version = ExerciseVersion.new(exercise: @ex,creator_id:
                 User.find_by(email: version['creator']).andand.id,
                 exercise: @ex,
                 position:1)
      @version.save!
      version['prompts'].each do |prompt|
        prompt = prompt['coding_prompt']
        @prompt = CodingPrompt.new(exercise_version: @version)
        @prompt.question = prompt['question']
        @prompt.position = prompt['position']
        @prompt.feedback = prompt['feedback']
        @prompt.class_name = prompt['class_name']
        @prompt.method_name = prompt['method_name']
        @prompt.starter_code = prompt['starter_code']
        @prompt.wrapper_code = prompt['wrapper_code']
        @prompt.test_script = prompt['tests']
        @prompt.actable_id = rand(100)
        @prompt.save!
      end

    end
    redirect_to exercises_path
  end


  # -------------------------------------------------------------
  # POST /exercises/upload_create
  def upload_create
    hash = YAML.load(File.read(params[:form][:file].path))
    exercises = ExerciseRepresenter.for_collection.new([]).from_hash(hash)
    exercises.each do |e|
      if !e.save
        # FIXME: Add these to alert message that can be sent back to user
        puts 'cannot save exercise, name = ' + e.name.to_s +
          ', external_id = ' + e.external_id.to_s + ': ' +
          e.errors.full_messages.to_s
        if e.current_version
          puts "    #{e.current_version.errors.full_messages.to_s}"
          if e.current_version.prompts.any?
            puts "    #{e.current_version.prompts.first.errors.full_messages.to_s}"
          end
        end
      end
    end

    redirect_to exercises_url, notice: 'Exercise upload complete.'
  end


  # -------------------------------------------------------------
  # GET/POST /practice/1
  def practice
    if params[:exercise_version_id]
      @exercise_version =
        ExerciseVersion.find_by(id: params[:exercise_version_id])
      if !@exercise_version
        redirect_to exercises_url, notice:
          "Exercise version EV#{params[:exercise_version_id]} " +
          "not found" and return
      end
      @exercise = @exercise_version.exercise
    elsif params[:id]
      @exercise = Exercise.find_by(id: params[:id])
      if !@exercise
        redirect_to exercises_url,
          notice: "Exercise E#{params[:id]} not found" and return
      end
      @exercise_version = @exercise.current_version
    else
      redirect_to exercises_url,
        notice: 'Choose an exercise to practice!' and return
    end

    # Tighter restrictions for the moment, should go away
    authorize! :practice, @exercise

    if session[:current_workout]
      @workout = Workout.find(session[:current_workout])
    end

    if params[:workout_offering_id]
      @workout_offering =
        WorkoutOffering.find_by(id: params[:workout_offering_id])
      if @workout_offering.time_limit_for(current_user)
        @user_time_limit = @workout_offering.time_limit_for(current_user)
      else
        @user_time_limit = nil
      end
    else
      @workout_offering = nil
    end

    if @exercise_version.is_mcq?
#      if Attempt.find_by(user: current_user, exercise_version: @exercise_version)
#        flash.notice = "You can't re-attempt MCQs"
#        redirect_to organization_workout_offering_practice_path(exercise_id: Exercise.find(3),
#           organization_id: @workout_offering.course_offering.course.organization.slug,
#           course_id: @workout_offering.course_offering.course.slug,
#           term_id: @workout_offering.course_offering.term.slug,
#           id: @workout_offering.id) and return
#      end
      @answers = @exercise_version.serve_choice_array
      @answers.each do |a|
        a[:answer] = markdown(a[:answer])
      end
    end
    @attempt = nil
    @workout_score = current_user.current_workout_score
    if @workout_offering &&
      @workout_score.workout_offering != @workout_offering
      @workout_score = nil
    end
    if @workout_offering && !@workout_score
      @workout_score = @workout_offering.score_for(current_user)
    end
    if @workout_score
      @attempt = @workout_score.attempt_for(@exercise_version.exercise)
    else
      @attempt = Attempt.joins{exercise_version}.
        where{(user_id == current_user.id) &
        (exercise_version.exercise_id == @exercise_version.exercise.id) &
        (workout_score_id == nil)}.first
    end
    @workout ||= @workout_score.workout
    if @workout_score.andand.closed? &&
      @workout_offering.andand.workout_policy.andand.no_review_before_close &&
      !@workout_offering.andand.shutdown?
      path = root_path
      if @workout_offering
        path = organization_workout_offering_path(
            organization_id:
              @workout_offering.course_offering.course.organization.slug,
            course_id: @workout_offering.course_offering.course.slug,
            term_id: @workout_offering.course_offering.term.slug,
            workout_offering_id: @workout_offering.id)
      elsif @workout
        path = workout_path(@workout)
      end
      redirect_to path,
        notice: "The time limit has passed for this workout." and return
    end
    if @workout.exercise_workouts.where(exercise: @exercise).any?
      @max_points = @workout.exercise_workouts.
        where(exercise: @exercise).first.points
      puts "\nMAX-POINTS", @max_points, "\nMAX-POINTS"
    end


    @responses = ['There are no responses yet!']
    @explain = ['There are no explanations yet!']
    if session[:leaf_exercises]
      session[:leaf_exercises] << @exercise.id
    else
      session[:leaf_exercises] = [@exercise.id]
    end
    # EOL stands for end of line
    # @wexs is the variable to hold the list of exercises of this workout
    # yet to be attempted by the user apart from the current exercise

    if params[:wexes] != 'EOL'
      @wexs = params[:wexes] || session[:remaining_wexes]
    else
      @wexs = nil
    end
    render layout: 'two_columns'
  end


  # -------------------------------------------------------------
  def create_choice
    @ans = Choice.create
    @pick.push()
  end


  # -------------------------------------------------------------
  #GET /evaluate/1
  def evaluate
    # Copy/pasted from #practice method.  Should be refactored.
    if params[:exercise_version_id]
      @exercise_version =
        ExerciseVersion.find_by(id: params[:exercise_version_id])
      if !@exercise_version
        redirect_to exercises_url, notice:
          "Exercise version EV#{params[:exercise_version_id]} " +
          "not found" and return
      end
      @exercise = @exercise_version.exercise
    elsif params[:id]
      @exercise = Exercise.find_by(id: params[:id])
      if !@exercise
        redirect_to exercises_url,
          notice: "Exercise E#{params[:id]} not found" and return
      end
      @exercise_version = @exercise.current_version
    else
      redirect_to exercises_url,
        notice: 'Choose an exercise to practice!' and return
    end

    # Tighter restrictions for the moment, should go away
    authorize! :practice, @exercise
    @workout = nil
    @workout_offering = nil
    if params[:workout_offering_id]
      @workout_offering =
        WorkoutOffering.find_by(id: params[:workout_offering_id])
      if @workout_offering &&
        !@workout_offering.workout.contains?(@exercise_version.exercise)
        @workout_offering = nil
      end
    else
      @workout_offering = nil
    end
    if @workout_offering.nil? && current_user.andand.current_workout_score &&
      current_user.current_workout_score.workout.contains?(@exercise_version.exercise)
      @workout_offering = current_user.current_workout_score.workout_offering
      if @workout_offering.nil?
        @workout = current_user.current_workout_score.workout
      end
    end
    if @workout_offering && @workout.nil?
      @workout = @workout_offering.workout
    end
    if @workout.nil? && session[:current_workout]
      @workout = Workout.find_by(id: session[:current_workout])
      if !@workout.contains?(@exercise_version.exercise)
        @workout = nil
      end
    end
    @workout_score = nil
    if @workout_offering
      @workout_score = @workout_offering.score_for(current_user)
    elsif @workout
      @workout_score = @workout.score_for(current_user)
    end

    if @workout_score.andand.closed? && @workout_offering.andand.can_be_practiced_by?(current_user)
      p 'WARNING: attempt to evaluate exercise after time expired.'
      return
    end

    # Instance variables used evaluate.js
    @is_perfect = false
    @attempt = @exercise_version.new_attempt(
      user: current_user, workout_score: @workout_score)
    @attempt.save!

    # FIXME: Need to make it work for multiple prompts
    prompt = @exercise_version.prompts.first.specific
    prompt_answer = @attempt.prompt_answers.first  # already specific here
    if @workout.andand.exercise_workouts.andand.where(exercise: @exercise).andand.any?
      @max_points = @workout.exercise_workouts.
        where(exercise: @exercise).first.points
    else # case when exercise being practised is not part of any workout
      @max_points = 10.0
    end
    if @exercise_version.is_mcq?
      #response_ids = params[:exercise_version][:multiple_choice_prompt][:choice_ids]
      response_ids = params[:exercise_version][:choice][:id]
      p params
      @responses = Array.new
      if @exercise_version.prompts.first.specific.allow_multiple
        response_ids.each do |r|
          @responses.push(Choice.find(r))
        end
      else
        @responses.push(Choice.find(response_ids))
      end
      @responses = @responses.compact
      @responses.each do |answer|
        answer[:answer] = markdown(answer[:answer])
      end
      prompt_answer.choices = @responses
      @score = @exercise_version.score(@responses)
      if @workout
        @score = @score * @max_points / @exercise_version.max_mcq_score
      end
      # TODO: Enable @explain and @exercise_feedback again
      #@explain = @exercise_version.collate_feedback(@responses)
      @exercise_feedback = 'You have attempted exercise '
      # + "#{@exercise.id}:#{@exercise.name}" +
      #  ' and its feedback for you: ' +
      #  @explain.to_sentence

      # TODO: calculate experience based on correctness and num submissions
      count_submission()
      @xp = @exercise_version.experience_on(@responses, session[:submit_num])

      @attempt.score = @score
      @attempt.feedback_ready = true
      @attempt.experience_earned = @xp
      @attempt.save!
      if @workout_score
        @workout_score.record_attempt(@attempt)
      end

      if @max_points <= @attempt.score ||
        !@workout_score.andand.show_feedback?
        @is_perfect = true
      end
      if @is_perfect && @workout_score.andand.workout
        flash.notice = "Your previous question's answer choice has been saved and scored"
        render :js => "window.location = '" +
          organization_workout_offering_practice_path(
          exercise_id: @workout_score.workout.next_exercise(@exercise, current_user, nil),
          organization_id: @workout_offering.course_offering.course.organization.slug,
          course_id: @workout_offering.course_offering.course.slug,
          term_id: @workout_offering.course_offering.term.slug,
          id: @workout_offering.id) + "' "
      end
    elsif @exercise_version.is_coding?
      prompt_answer.answer = params[:exercise_version][:answer_code]
      if prompt_answer.save
        CodeWorker.new.async.perform(
          @attempt.id,
          @workout_score.andand.id)
      else
        puts 'IMPROPER PROMPT',
          'unable to save prompt_answer: ' \
          "#{prompt_answer.errors.full_messages.to_s}",
          'IMPROPER PROMPT'
      end
      @workout ||= @workout_score.andand.workout
    end

  end


  # -------------------------------------------------------------
  # PATCH/PUT /exercises/1
  def update
    new_exercise = create_new_version()
    @exercise.base_exercise.exercises << new_exercise
    new_exercise.save
    @exercise.base_exercise.current_version = new_exercise
    @exercise.base_exercise.save
    if new_exercise.update_attributes(exercise_params)
      respond_to do |format|
        format.html do
          redirect_to new_exercise,
            notice: 'Exercise was successfully updated.'
        end
        format.json { head :no_content } # 204 No Content
      end
    else
      respond_to do |format|
        format.html { render action: 'edit' }
        format.json do
          render json: new_exercise.errors, status: :unprocessable_entity
        end
      end
    end
  end


  # -------------------------------------------------------------
  # DELETE /exercises/1
  def destroy
    @exercise.destroy
    redirect_to exercises_url, notice: 'Exercise was successfully destroyed.'
  end


  #~ Private instance methods .................................................
  private

    # -------------------------------------------------------------
    def create_new_version
      newexercise = Exercise.new
      newexercise.name = @exercise.name
      newexercise.creator_id = current_user.id
      newexercise.question = @exercise.question
      newexercise.feedback = @exercise.feedback
      newexercise.is_public = @exercise.is_public
      newexercise.mcq_allow_multiple = @exercise.mcq_allow_multiple
      newexercise.mcq_is_scrambled = @exercise.mcq_is_scrambled
      newexercise.priority =  @exercise.priority
      # TODO: Get the count of attempts from the session
      newexercise.count_attempts = 0
      newexercise.count_correct = 0
      newexercise.experience = @exercise.experience
      newexercise.version = @exercise.base_exercise.versions =
        @exercise.version + 1
      # default IRT statistics
      newexercise.difficulty = 5
      newexercise.discrimination = @exercise.discrimination
      return newexercise
    end


    # -------------------------------------------------------------
    # Only allow a trusted parameter "white list" through.
    def exercise_params
      params.require(:exercise_version).permit(:name, :question, :feedback,
        :experience, :id, :is_public, :priority, :type,
        :exercise_version, :exercise_version_id, :commit,
        :mcq_allow_multiple, :mcq_is_scrambled, :language, :area,
        choices_attributes: [:answer, :order, :value, :_destroy],
        tags_attributes: [:tag_name, :tagtype, :_destroy])
    end


    # -------------------------------------------------------------
    def count_submission
      if !session[:exercise_id] ||
        session[:exercise_id] != params[:id] ||
        !session[:submit_num]

        # TODO: look up only current user
        recent = Attempt.where(user_id: 1).where(
          exercise_version_id: params[:exercise_version_id]).
          sort_by { |a| a[:submit_num] }
        if !recent.empty?
          session[:submit_num] = recent.last[:submit_num] + 1
        else
          session[:submit_num] = 1
        end
      else
        session[:submit_num] +=  1
      end
    end

end
