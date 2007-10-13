# ARID provides a simple & DRY method of writing intergration tests for RESTful controllers
# and views that follow standard conventions.
#
# * Checks that controllers respond as expected to different methods.
# * On <tt>create</tt> and <tt>update</tt> tests, confirms that forms
#   in <tt>new</tt> and <tt>edit</tt> views contain the correct action,
#   method, and inputs to submit the data that the test wants to submit.
# * Performs AJAX requests instead of standard requests simply by
#   passing the <tt>:via_ajax => true</tt> option with your test.
# * Accepts blocks with tests to perform additional application
#   specific tests.
#
# Complete API Documentation @
# * Session Instantiation -- ActiveResourceIntegrationDsl  
# * Session Methods -- ActiveResourceIntegrationDsl::SessionMethods

module ActiveResourceIntegrationDsl
  
  # Logs in a user to the application via a SessionsController.  Assumes that you have
  # a RESTful SessionsController with routes setup accordingly and that this is 
  # how users are expected to login to your application. Pass a block to
  # perform additional tests as the newly logged in user.
  #
  # === Requirements
  # * Routes must setup new_session_path and sessions_path helper.
  # * <tt>new</tt> action must provide a login form with a POST method to <tt>sessions_path</tt>
  #   and text fields named <tt>user[username]</tt> and <tt>user[password]</tt>.
  # * <tt>create</tt> action in controller must accept credentials in the params hash
  #   in the following format.
  #    {:user => {:username => 'user_login_name', :password => 'users_password'}}
  # * <tt>create</tt> method must respod with a <tt>304 (Redirect)</tt> on a successfull login.
  #   It doesn't matter where the redirect is to.
  #
  # === Usage Example
  # The following will test a user loging in to the application and then performing a GET on
  # the UsersController <tt>index</tt> action.
  #
  # 
  #   def test_read_users_index
  #     new_session_as('admin','password') do |admin|
  #       admin.reads_users
  #     end
  #   end
  #
  def new_session_as(user,pass)
    new_session do |guest|
      guest.creates_session(
        :params => {
          :user => {
            :username => user,
            :password => pass
          }
        }
      ) 
      yield guest if block_given?
      guest.destroys_session('this')
    end
  end
  
  # Initiates a new session as a guest user (i.e. not logged in).
  #
  # === Sample
  #  def test_prepare_for_login
  #    new_session do |guest|
  #      guest.reads(new_session_path)
  #    end
  #  end
  def new_session
    open_session do |sess|
      sess.extend(SessionMethods)
      yield sess if block_given?
    end
  end
  
  # All of the following methods apply to sessions created with <tt>new_session</tt>
  # or <tt>new_session_as</tt>. All samples on this page are assumed to exist inside a
  # <tt>new_session_as</tt> block with <tt>user</tt> representing the session object.
  # For instance...
  #   new_session_as('user','password') do |user|
  #     user.lists_tickets  # 'user' does GET to tickets_path 
  #   end
  #
  # The standard style of writing integration tests with ARID is very similar to using
  # RESTful path helpers. Typical Rails magic deduces what you are trying to test based
  # on the method you call on your session object. Several session instance methods
  # are also provided should your unique scenario prevent the use of the magic methods,
  # but in most cases where you are following Rails conventions, the magic methods
  # should be sufficient. 
  # 
  # All Arid magic methods begin with one of several prefixes that begin to describe 
  # what the logged in user will be doing. These prefixes are shown in the following,
  # list with their corresponding controller actions. Each will be explained in more
  # detail below.
  # * <tt>lists_</tt> -- <tt>index</tt>
  # * <tt>shows_</tt> -- <tt>show</tt>
  # * <tt>builds_</tt> --  <tt>new</tt>
  # * <tt>creates_</tt> -- <tt>create</tt>
  # * <tt>edits_</tt> -- <tt>edit</tt>
  # * <tt>updates_</tt> -- <tt>update</tt>
  # * <tt>destroys_</tt> -- <tt>destroy</tt>
  # * <tt>exercies_</tt> -- Full CRUD testing of simple/scaffold generated RESTful controllers.
  #
  # Each of the above prefixes is followed by a description of the action that is
  # derived from the RESTful helpers provided by <tt>map.resources</tt> calls in the
  # routes.rb. For instance, if the _path method you would use in a link_to method in your view
  # was something like <tt>new_article_comment_path(@article)</tt> then a corresponding
  # ARID test would look something like <tt>user.builds_article_comment(@article)</tt>.
  # Or, if the form tag to create a comment looked something like
  # <tt><% form_for :comment, :url => comments_path do |form| %></tt> then the
  # corresponding ARID test to test the submission of this form would look something
  # like <tt>user.creates_comment(:params => {:comment => {:subject => 'Wow!', :body => 'This is cool!'}})</tt>.
  # Note how in this last example, the path method in the form tag uses <tt>_comment<b>s</b></tt>,
  # (plural) but the ARID uses <tt>_comment</tt> (singular).
  #  
  # All ARID methods accept a block that you pass the response to for doing application
  # specific assertions. For instance...
  #   user.shows_article(@article) do |page|
  #     page.assert_select "div[id='title']", @article.title 
  #   end
  #
  # = lists_ & shows_ Prefixes
  # Each of these perform a GET request to either the <tt>index</tt> or <tt>show</tt> actions
  # of the controller, depending on the path provided. These are actually aliases for the same
  # method and are technically interchangeable. Determining which controller action gets
  # called is based entirely on the given path and your settings in routes.rb. It is
  # recommended that you use the prefix that 'sounds' correct in the context of the controller
  # action you are testing. For example, <tt>user.lists_comment(1)</tt> and
  # <tt>user.shows_comment(1)</tt> would both trigger the <tt>show</tt> action and work equally
  # well, but only one sounds correct. Likewise, <tt>user.lists_comments</tt> and
  # <tt>user.shows_comments</tt> both sound correct, but one should sound <b>more</b> correct, 
  # especially to an experienced Rails developer.
  # === Arguments
  # After any ids or ActiveRecord objects necessary to generate the path, you may include
  # a hash with any of the following keys.
  # * <tt>:via_ajax</tt> -- Set to <b>true</b> to perform <tt>xml_http_request</tt>
  #   instead of standard <tt>http</tt> request. (Default: false).
  # * <tt>:expects</tt> -- See <tt>assert_response</tt> in Rails API for list of availble options.
  #   (Default: :success).  If <tt>:expected_response => :redirect</tt> and no block is given, will
  #   follow redirect and assert :success.
  # * <tt>:headers</tt> -- A hash of additional or alternate HTTP Headers to pass with the request. Useful
  #   if the tested application is expected to behave differently based on certain request headers.
  # === Assertions 
  # * Response is a success, unless <tt>:expected_response</tt> option provided with otherwise.
  # === Samples
  # * <tt>user.lists_tickets</tt> -- GET to tickets_path (/tickets).
  # * <tt>user.shows_ticket(1)</tt> -- GET to ticket_path(1) (/tickets/1).
  # * <tt>user.lists_isle_row_shelf_books(@isle,@row,@shelf)</tt>
  # * <tt>user.lists_post_comments(@post) {|page| page.assert_select 'h1', @post.title }</tt>
  # * <tt>user.shows_ticket(1,{:via_ajax => true}) {|page| page.assert_select_rjs :replace_html, 'show_ticket' }</tt>
  # * <tt>user.lists_tickets({:headers => {:http_host => 'alternate.example.com'}})</tt>
  #
  # = builds_ and edits_ Prefixes
  # Trigger the <tt>new</tt> or <tt>edit</tt> action in the controller respectively. Optionally take a
  # <tt>:params</tt> hash option which unlocks more magic (see below).
  # === Arguments  
  # After any ids or ActiveRecord objects necessary to generate the path, you may include
  # a hash with any of the following keys.
  # * <tt>:expects</tt> -- See <tt>assert_response</tt> in Rails API for list of availble options.
  #   (Default: :success).  Not compatible with <tt>:params</tt> option.
  # * <tt>:headers</tt> -- A hash of additional or alternate HTTP Headers to pass See <b>Show</b> above for sample.
  # * <tt>:params</tt> -- A hash representative of the params that would be passed back to the
  #   controller when the form is submitted. Not compatible with the :expect 
  # === Basic Assertions
  # * GET responds with :success.
  # === Advanced Assertions with :params option.
  # If you provide a <tt>:params</tt> hash option, ARID will also assert that the reponse includes a
  # form on the page, and assert that the form includes... 
  # * the correct path to submit the form back to.
  # * the form method set to POST.
  # * a hidden field with the name <tt>method</tt> and a value of <tt>put</tt> if the called with <tt>edits_</tt>.
  # * appropriate form fields for all params passed. For instance, if the params
  #   <tt>{:article => {:subject => 'Hello World!'}}</tt> is passed, ARID will confirm that the form
  #   contains <tt><input name='article[subject]'></tt>. (Also checks for <tt><text_area></tt> and 
  #   <tt><select></tt> tags.)
  # Next ARID will forward all of your arguments to <tt>creates_</tt> or <tt>updates_</tt> to submit the form, assert
  # the response is a :redirect, follow the :redirect and assert next response is :success.
  # === Samples
  # * <tt>user.builds_comment</tt> -- Trigger <tt>/comments/new</tt>
  # * <tt>user.edits_comment(@comment)</tt> -- Trigger <tt>/comments/1;edit</tt> 
  # * <tt>user.builds_article(:params => {:article => {:title => 'Hello World!', :body => 'This is only a test.'}})</tt> --
  #   Trigger <tt>/articles/1</tt>, assert response is :success, parse the form and assert that it's valid to submit
  #   the provided params, then submit it and assert response is :redirect, follow the :redirect and assert :success.
  #
  # = creates_ and updates_ Prefixes
  # Trigger the <tt>create</tt> or <tt>update</tt> action in the controller respectively.
  # === Arguments
  # After any ids or ActiveRecord objects necessary to generate the path, you may include
  # a hash with any of the following keys.
  # * <tt>:params</tt> -- The params hash to pass to the controller action.
  # * <tt>:expects</tt> -- See <tt>assert_response</tt> in Rails API for list of availble options.
  #   This is what you expect the reponse to be after the POST. (Default: :redirect). If
  #   <tt>:expects => :redirect</tt> and no block is given, will follow redirect and assert :success.
  # * <tt>:headers</tt> -- A hash of additional or alternate HTTP Headers to pass with the POST. (Does not apply
  #   to the GET). See <b>Show</b> above for sample.
  # === Assertions
  # * Response is :redirect, unless :expects option passed.
  # * Follows :redirect and asserts :success unless block passed.
  # === Samples
  # * <tt>user.updates_article(:params => {:article => {:title => 'Hello World!', :body => 'This is only a test.'}})</tt> --
  #   PUT to <tt>/articles</tt>, assert response is :redirect, follow and assert :success.
  # * <tt>user.creates_forum_thread(@forum,:params => {:thread => {:subject => 'Flame War!', :contents => 'I B Flamin Yall!'}})</tt> --
  #   POST to <tt>/forums/42/articles</tt>, assert response is :redirect, follow and assert :success.
  # *  user.creates_session(
  #      :params => {
  #         :user => {
  #            :username => 'captainbuggernuts',
  #            :password => 'mychippies'
  #         }
  #       },
  #       :expects => :success) do |page|
  #      page.assert_select "div[id='error_messages']", 'Login Failed'
  #    end
  #
  #
  # = destroys_ Prefix
  # Triggers <tt>destroy</tt> action in controller.
  # === Arguments
  # After any ids or ActiveRecord objects necessary to generate the path, you may include
  # a hash with any of the following keys.
  # * <tt>:via_ajax</tt> -- Set to <b>true</b> to perform <tt>xml_http_request</tt>
  #   instead of standard <tt>http</tt> request. (Default: false).
  # * <tt>:expects</tt> -- See <tt>assert_response</tt> in Rails API for list of availble options.
  #   (Default: :redirect).  If <tt>:expects => :redirect</tt> and no block is given, will
  #   follow redirect and assert :success.
  # * <tt>:headers</tt> -- A hash of additional or alternate HTTP Headers to pass with the request.
  # === Assertions
  # * Response is a redirect, unless <tt>:expects</tt> option provided.
  # * Follows redirect and asserts response is :success unless :expects is not :redirect or block is passed. 
  # === Samples
  # * <tt>user.destroys_ticket(1)</tt>
  # * <tt>user.destroys_post(@post,{:expects => :success}) {|page| page.assert_select :flash_warning, 'Permission Denied' }</tt>
  # * <tt>user.destroys_comment(@comment,{:via_ajax => true}) {|page| page.assert_select_rjs :replace_html, 'feedback' }</tt>
  #
  # = exercises_ Prefix
  # This test is usually only useful on the most basic controllers, ie, scaffold generated and mostly unedited. But for those
  # controllers, it's a quick easy way to boost your test coverage. It will walk through the entire process of creating,
  # updating, and destroying an object, making standard assertions along the way.
  # === Arguments
  # * <tt>:new_params</tt> -- Params to use with the <tt>new</tt> and <tt>create</tt> actions.
  # * <tt>:update_params</tt> -- Params to use with the <tt>edit</tt> and <tt>update</tt> actions.
  # * Options Hash
  #   * <tt>:expected_not_found_response</tt> -- Defailt is HTTP 404.
  # === Samples
  # * <tt>user.exercises_articles({:article => {:title => 'Excercise be Good', :content => 'New study proves it.'}},{:article => {:subject => 'Exercise is Good'}})</tt> 
  # 
  module SessionMethods
    
    # See above documentation for SessionMethods
    def method_missing( method_sym, *args, &block ) #:nodoc:
      if method_sym.to_s =~ /^(lists|shows|builds|creates|edits|updates|destroys|exercises)_(.*)/
        self.send($1.to_sym,$2.to_sym,*args,&block)
      else
        super
      end
    end
    
    # Resort to this only when unable to use magic methods described above.
    # 
    # === Samples
    # * <tt>user.lists(:article_comments,@article)</tt>
    # * <tt>user.shows(:comment,@comment,{:via_ajax => true})</tt>
    def shows(object,*args,&block)
      opts = args.last.is_a?(Hash) ? args.pop.symbolize_keys : {}
      goes_to(path_for(object,args),opts,&block)
    end
    alias_method :lists, :shows
    
    # Resort to this only when unable to use magic methods described above.
    #
    # === Samples
    # * <tt>user.builds(:article_comment,@article,{:params => )</tt>
    def builds(object,*args,&block)
      opts = args.last.is_a?(Hash) ? args.pop.symbolize_keys : {}
      params = opts.delete(:params)
      goes_to(new_path_for(object,args)) do |page|
        check_form_on(page,self.send("#{object.to_s.pluralize}_path",*args),:post,params,opts) if params
      end
      creates(object,*args + [opts.merge(:params => params)],&block)
    end
    
    # Resort to this only when unable to use magic methods described above.
    # 
    # === Sample
    # * <tt>user.creates(:forum_post,@forum,{:post => {:title => 'X', :body => 'Y'}})</tt>
    def creates(object,*args,&block)
      opts = args.last.is_a?(Hash) ? args.pop.symbolize_keys : {}
      params = opts.delete(:params)
      posts_to(path_for(object.to_s.pluralize,args),params,opts,&block)
    end
    
    # Resort to this only when unable to use magic methods described above.
    #
    # === Samples
    # * <tt>user.builds(:article_comment,@article,{:params => )</tt>
    def edits(object,*args,&block)
      opts = args.last.is_a?(Hash) ? args.pop.symbolize_keys : {}
      params = opts.delete(:params)
      goes_to(edit_path_for(object,args)) do |page|
        check_form_on(page,path_for(object,args),:put,params,opts) if params
      end
      updates(object,*args + [opts.merge(:params => params)],&block)
    end
    
    # Resort to this only when unable to use magic methods described above.
    # 
    # === Sample
    # * <tt>user.updates(:forum_post,@forum,@post,{:post => {:title => 'Z'}})</tt>
    def updates(object,*args,&block)
      opts = args.last.is_a?(Hash) ? args.pop.symbolize_keys : {}
      params = opts.delete(:params)
      puts_to(path_for(object,args),params,opts,&block)
    end
    
    # Resort to this only when unable to use magic methods described above.
    # 
    # === Sample
    # * <tt>user.deletes(:post,@post)</tt>
    def destroys(object,*args,&block)
      opts = args.last.is_a?(Hash) ? args.pop.symbolize_keys : {}
      deletes_to(path_for(object,args),opts,&block)
    end
    
    # Resort to this only when unable to use magic methods described above.
    # 
    def exercises(object,new_params,update_params,opts={}) #:nodoc:
      id = nil #initialize
      
      #Create
      builds(object,new_params) do |page|
        id = get_id_from_url(page.response.redirected_to)
        page.follow_redirect!
        page.assert_response :success
      end
      
      #Read
      shows(object,id) do |page|
        assert_equal(id,page.assigns(object).id)
      end
      
      #Update
      edits(object,id,update_params) do |page|
        di = get_id_from_url(page.response.redirected_to)
        assert_equal(id,di)
        page.follow_redirect!
        page.assert_response :success
      end
      
      #Destroy
      destroys(object,id)
      reads(object,id,{:expected_response => opts[:expected_not_found_response] || 404})
    end
    
    
    # Resort to this only when unable to use the 'reads' method or the magic methods described above.
    # 
    def goes_to(path,opts={},&block) #:nodoc: 
      opts.reverse_merge!({:expects => :success})
      crud_to(:get,path,opts[:params] || {},opts,&block)
    end
    
    # Resort to this only when unable to use magic methods described above or you really only
    # want to test a raw POST without worrying about the form.
    # 
    def posts_to(path,params,opts={},&block) #:nodoc: 
      crud_to(:post,path,params,opts,&block)
    end
    
    # Resort to this only when unable to use magic methods described above or you really only
    # want to test a raw PUT without worrying about the form.
    # 
    def puts_to(path,params,opts={},&block) #:nodoc: 
      crud_to(:put,path,params,opts,&block)
    end
    
    # Resort to this only when unable to use the 'deletes' method or the magic methods described above.
    # 
    def deletes_to(path,opts={},&block) #:nodoc: 
      crud_to(:delete,path,opts[:params] || {},opts,&block)
    end
    
    #######
    private
    #######
    
    def crud_to(method,path,params,opts={})
      if opts[:via_ajax]
        opts.reverse_merge!({:expects => :success})
        self.send(:xhr,method,path,params,opts[:headers])
      else 
        opts.reverse_merge!({:expects => :redirect})
        self.send(method,path,params,opts[:headers])
      end
      assert_response(opts[:expects],
        "#{'AJAX ' if opts[:via_ajax]}Failed to get #{opts[:expects]} on #{method} to #{path}.")
      #let block follow it's own redirects if it so desires
      if block_given?
        yield self 
      elsif opts[:expects] == :redirect    
        follow_redirect!
        assert_response :success
      end
    end
    
    def check_form_on(page,action,method,params,opts={})
      page.assert_select "form[action='#{action}'][method='post']#{'[onsubmit]' if opts[:via_ajax]}", true,
        "Expected page to contain <form> element with action='#{action}' and method='post'#{'with onsubmit' if opts[:via_ajax]}." do
        if method == :put
          page.assert_select "input[name='_method'][type='hidden'][value='put']", true,
            "Expected hidden input with name='_method' and value='put'."
        end
        params.each do |topkey,topval|
          if topval.is_a?(Hash)
            topval.each_key do |nextkey|
              page.assert_select "input[name='#{topkey}[#{nextkey}]'],textarea[name='#{topkey}[#{nextkey}]'],select[name='#{topkey}[#{nextkey}]']", true,
                "Expected <form> to contain <input> element with name='#{topkey}[#{nextkey}]'."
            end
          else
            page.assert_select "input[name='#{topkey}'],textarea[name='#{topkey}'],select[name='#{topkey}']", true,
              "Expected <form> to contain <input> element with name='#{topkey}'."
          end
        end
      end
    end
    
    def get_id_from_url(url)
      regex = /http:\/\/www\.example\.com\/.+\/(\d+)/
      match = regex.match(url)
      assert_not_nil(match,"Failed to find story ID in redirected URL: #{url}")
      return match[1].to_i
    end
    
    def path_for(object,ids = nil)
      self.send(object.to_s+'_path',*ids)
    end
    
    def new_path_for(obj,ids = nil)
      intermediate_path_for(:new,obj,ids)
    end
    
    def edit_path_for(obj,ids = nil)
      intermediate_path_for(:edit,obj,ids)
    end
    
    def intermediate_path_for(action,obj,ids = nil)
      action = action.to_s
      return path_for("#{action}_#{obj.to_s}",ids) if self.respond_to?("#{action}_#{obj.to_s}_path")
      # Rails1.2 compatability section. We never get here in 2.0. Remove eventually.
      post_elements = obj.to_s.split(/_/)
      pre_elements = []
      until post_elements.blank? do
        pre_elements << post_elements.shift
        ipath = "#{pre_elements * '_'}_#{action}_#{post_elements * '_'}"
        return path_for(ipath,ids) if self.respond_to?(ipath+'_path')
      end
      raise(RuntimeError,"Couldn't find '#{action}' path for #{obj.to_s}.")
    end
  end
end


module ActionController #:nodoc: 
  module Integration #:nodoc: 
    class Session 
      
      # This overrides the Rails builtin xml_http_request and is a temporary workaround
      # to allow testing RESTful Ajaxy calls. The patch has been applied to Rails 2.0, so this
      # can probably be removed from ARID when that's released.
      #
      # ==== See: http://dev.rubyonrails.org/ticket/7124
      def xml_http_request(request_method, path, parameters = nil, headers = nil) 
        unless request_method.is_a?(Symbol) 
          ActiveSupport::Deprecation.warn 'xml_http_request now takes the request_method (:get, :post, etc.) as the first argument. It used to assume :post, so add the :post argument to your existing method calls to silence this warning.' 
            request_method, path, parameters, headers = :post, request_method, path, parameters
        end

        headers ||= {}
        headers['X-Requested-With'] = 'XMLHttpRequest'
        headers['Accept'] = 'text/javascript, text/html, application/xml, text/xml, */*'
        process(request_method, path, parameters, headers)
      end
      alias xhr :xml_http_request
    end
  end
end