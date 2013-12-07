class RegisterInlineForm extends LoginViewInlineForm

  constructor:(options={},data)->
    super options, data

    # @fullName = new LoginInputView
    #   inputOptions    :
    #     name          : "fullName"
    #     placeholder   : "full name"
    #     validate      :
    #       container   : this
    #       event       : "blur"
    #       rules       :
    #         required  : yes
    #       messages    :
    #         required  : "Please enter your name."
    #     testPath      : "register-form-fullname"

    @firstName = new LoginInputView
      cssClass          : "half-size"
      inputOptions      :
        name            : "firstName"
        placeholder     : "first name"
        validate        :
          notifications :
            type        : 'tooltip'
            placement   : 'left'
            direction   : 'right'
          container     : this
          rules         :
            required    : yes
          messages      :
            required    : "Please enter your first name."
        testPath        : "register-form-firstname"

    @lastName = new LoginInputView
      cssClass        : "half-size"
      inputOptions    :
        name          : "lastName"
        placeholder   : "last name"
        validate      :
          container   : this
          rules       :
            required  : yes
          messages    :
            required  : "Please enter your last name."
        testPath      : "register-form-lastname"

    @email = new LoginInputViewWithLoader
      inputOptions    :
        name          : "email"
        placeholder   : "email address"
        testPath      : "register-form-email"
        validate      : @getEmailValidator()
        blur          : (input, event)=>
          @utils.defer =>
            @userAvatarFeedback input

    @avatar = new AvatarStaticView
      size        :
        width     : 55
        height    : 55
    , profile     :
        hash      : md5.digest "there is no such email"
        firstName : "New koding user"
    @avatar.hide()

    @username = new LoginInputViewWithLoader
      inputOptions       :
        name             : "username"
        forceCase        : "lowercase"
        placeholder      : "username"
        testPath         : "register-form-username"
        keyup            : =>

          if (val = @username.input.getValue()).trim() isnt ''
            @domain.updatePartial "#{val}.kd.io"
          else
            @domain.updatePartial "username.kd.io"

        validate         :
          container      : this
          rules          :
            required     : yes
            rangeLength  : [4,25]
            regExp       : /^[a-z\d]+([-][a-z\d]+)*$/i
            usernameCheck: (input, event)=> @usernameCheck input, event
            finalCheck   : (input, event)=> @usernameCheck input, event, 0
          messages       :
            required     : "Please enter a username."
            regExp       : "For username only lowercase letters and numbers are allowed!"
            rangeLength  : "Username should be between 4 and 25 characters!"
          events         :
            required     : "blur"
            rangeLength  : "keyup"
            regExp       : "keyup"
            usernameCheck: "keyup"
            finalCheck   : "blur"

    # @password = new LoginInputView
    #   inputOptions    :
    #     name          : "password"
    #     type          : "password"
    #     placeholder   : "Create a password"
    #     testPath      : "register-form-pass1"
    #     validate      :
    #       container   : this
    #       event       : "blur"
    #       rules       :
    #         required  : yes
    #         minLength : 8
    #       messages    :
    #         required  : "Password is required."
    #         minLength : "Password should at least be 8 characters."

    # @passwordConfirm = new LoginInputView
    #   cssClass        : "password-confirm"
    #   inputOptions    :
    #     name          : "passwordConfirm"
    #     type          : "password"
    #     placeholder   : "Confirm your password"
    #     testPath      : "register-form-pass2"
    #     validate      :
    #       container   : this
    #       event       : "blur"
    #       rules       :
    #         required  : yes
    #         match     : @password.input
    #         minLength : 8
    #       messages    :
    #         required  : "Password confirmation required!"
    #         match     : "Password confirmation doesn't match!"

    @button = new KDButtonView
      title         : "CREATE ACCOUNT"
      type          : 'submit'
      style         : "solid green"
      loader        :
        color       : "#ffffff"
        diameter    : 21

    @disabledNotice = new KDCustomHTMLView
      tagName       : "section"
      cssClass      : "disabled-notice"
      partial       : """
                      <p>
                      <b>REGISTRATIONS ARE CURRENTLY DISABLED</b>
                      We're sorry for that, please follow us on <a href='http://twitter.com/koding' target='_blank'>twitter</a>
                      if you want to be notified when registrations are enabled again.
                      </p>
                      """

    @invitationCode = new LoginInputView
      cssClass      : "hidden"
      inputOptions  :
        name        : "inviteCode"
        type        : 'hidden'

    @domain = new KDCustomHTMLView
      tagName : 'strong'
      partial : 'username.kd.io'

    @on "SubmitFailed", (msg)=>
      # if msg is "Wrong password"
      #   @passwordConfirm.input.setValue ''
      #   @password.input.setValue ''
      #   @password.input.validate()

      @button.hideLoader()

  usernameCheckTimer = null

  reset:->
    inputs = KDFormView.findChildInputs this
    input.clearValidationFeedback() for input in inputs
    super

  usernameCheck:(input, event, delay=800)->
    return if event?.which is 9
    return if input.getValue().length < 4

    clearTimeout usernameCheckTimer
    input.setValidationResult "usernameCheck", null
    name = input.getValue()

    if input.valid
      usernameCheckTimer = setTimeout =>
        @username.loader.show()
        KD.remote.api.JUser.usernameAvailable name, (err, response)=>
          @username.loader.hide()
          {kodingUser, forbidden} = response
          if err
            if response?.kodingUser
              input.setValidationResult "usernameCheck", "Sorry, \"#{name}\" is already taken!"
          else
            if forbidden
              input.setValidationResult "usernameCheck", "Sorry, \"#{name}\" is forbidden to use!"
            else if kodingUser
              input.setValidationResult "usernameCheck", "Sorry, \"#{name}\" is already taken!"
            else
              input.setValidationResult "usernameCheck", null
      , delay

  userAvatarFeedback:(input)->
    if input.valid
      @avatar.setData
        profile     :
          hash      : md5.digest input.getValue()
          firstName : "New koding user"
      @avatar.render()
      @showUserAvatar()
    else
      @hideUserAvatar()

  showUserAvatar:-> @avatar.show()

  hideUserAvatar:-> @avatar.hide()

  viewAppended:->

    super

    KD.getSingleton('mainController').on 'InvitationReceived', (invite)=>
      @$('.invitation-field').addClass('hidden')
      @$('.invited-by').removeClass('hidden')
      {origin} = invite
      @invitationCode.input.setValue invite.code
      @email.input.setValue invite.email
      if origin.constructorName is 'JAccount'# instanceof KD.remote.api.JAccount
        KD.remote.cacheable [origin], (err, [account])=>
          @addSubView new AvatarStaticView({size: width : 30, height : 30}, account), '.invited-by .wrapper'
          @addSubView new ProfileTextView({}, account), '.invited-by .wrapper'
      else
        @$('.invited-by').addClass('hidden')

  getEmailValidator: ->
    container   : this
    event       : "blur"
    rules       :
      required  : yes
      email     : yes
      available : (input, event)=>
        return if event?.which is 9
        input.setValidationResult "available", null
        email = input.getValue()
        if input.valid
          @email.loader.show()
          KD.remote.api.JUser.emailAvailable email, (err, response)=>
            @email.loader.hide()
            if err then warn err
            else
              if response
                input.setValidationResult "available", null
              else
                input.setValidationResult "available", "Sorry, \"#{email}\" is already in use!"
              @userAvatarFeedback input
        return
    messages    :
      required  : "Please enter your email address."
      email     : "That doesn't seem like a valid email address."

  pistachio:->
    """
    <section class='main-part'>
      <div class='email'>{{> @avatar}}{{> @email}}</div>
      <div>{{> @firstName}}{{> @lastName}}</div>
      <div class='username'>{{> @username}}</div>
      <div class='invitation-field invited-by hidden'>
        <span class='icon'></span>
        Invited by:
        <span class='wrapper'></span>
      </div>
      <div class='hint'>Your username must be at least 4 characters and it’s also going to be your {{> @domain}} domain.</div>
      <div>{{> @button}}</div>
    </section>
    {{> @invitationCode}}
    {{> @disabledNotice}}
    """
      # <div>{{> @fullName}}</div>
    #   <div>{{> @password}}</div>
    #   <div>{{> @passwordConfirm}}</div>
