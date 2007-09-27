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
      guest.creates_session({
        :user => {
          :username => user,
          :password => pass
        }
      }) 
      yield guest if block_given?
      guest.deletes_session('this')
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
  #     user.reads_tickets  # 'user' does GET to tickets_path 
  #   end
  #
  # Thanks to a little <tt>method_missing</tt> magic, The standard style of writing integration
  # tests for ARID is very similar to using RESTful path helpers. Several instance methods
  # are also provided should you not be able to use the magic methods, but in most cases
  # where you're following Rails conventions, the magic methods should be sufficient. 
  # 
  # = Show
  # Use the <tt>reads</tt> prefix to perform a GET, followed by the path helper to read.
  # === Arguments
  # Requires ActiveRecord objects or Integers representing id's suitable for passing to path methods,
  # followed by an optional hash containing...
  # * <tt>:via_ajax</tt> -- Set to <b>true</b> to perform <tt>xml_http_request</tt>
  #   instead of standard <tt>http</tt> request. (Default: false).
  # * <tt>:expected_response</tt> -- See <tt>assert_response</tt> in Rails API for list of availble options.
  #   (Default: :success).  If <tt>:expected_response => :redirect</tt> and no block is given, will
  #   follow redirect and assert :success.
  # * <tt>:headers</tt> -- A hash of additional or alternate HTTP Headers to pass with the request. Useful
  #   if the tested application is expected to behave differently based on certain request headers.   
  # === Assertions 
  # * Response is a success, unless <tt>:expected_response</tt> option provided with otherwise.
  # === Samples
  # * <tt>user.reads_tickets</tt> -- GET to tickets_path (/tickets).
  # * <tt>user.reads_ticket(1)</tt> -- GET to ticket_path(1) (/tickets/1).
  # * <tt>user.reads_isle_row_shelf_books(@isle,@row,@shelf)</tt>
  # * <tt>user.reads_post_comments(@post) {|page| page.assert_select 'h1', @post.title }</tt>
  # * <tt>user.reads_ticket(1,{:via_ajax => true}) {|page| page.assert_select_rjs :replace_html, 'show_ticket' }</tt>
  # * <tt>user.reads_tickets({:headers => {:http_host => 'alternate.example.com'}})</tt>
  #
  # = Create
  # Use the <tt>creates</tt> prefix followed by the path helper as a singular.
  # === Arguments
  # Requires ActiveRecord objects or Integers representing id's suitable for passing to path methods,
  # followed by a required params hash and an optional hash containing...
  # * <tt>:expected_response</tt> -- See <tt>assert_response</tt> in Rails API for list of availble options.
  #   This is what you expect the reponse to be after the POST. (Default: :redirect).  If
  #   <tt>:expected_response => :redirect</tt> and no block is given, will follow redirect and assert :success.
  # * <tt>:headers</tt> -- A hash of additional or alternate HTTP Headers to pass with the POST. (Does not apply
  #   to the GET). See <b>Show</b> above for sample.
  #
  # === Assertions
  # * GET to <tt>new_object_path</tt> responds with :success.
  # * Form on <tt>new</tt> page includes
  #   * <tt>action='/objects'</tt>
  #   * <tt>method='POST'</tt>.
  #   * appropriate inputes for all params passed. For instance, if the hash
  #     <tt>{:article => {:subject => 'Hello World!'}}</tt> is passed, will confirm that the form
  #     contains <tt><input name='article[subject]'></tt>
  # * POST to <tt>objects_path</tt> responds with :redirect
  # === Samples
  # * Successfully submit new article...
  #      user.creates_article({:article => {:title => 'Hello World!', :body => 'This is only a test.'}})
  # * Fail to login...
  #      guest.creates_session({:user => {:username => 'myuser', :password => 'badpass'}},{:expected_response => :success) do |page|
  #        page.assert_select :flash_warning, 'Password Incorrect!'
  #      end
  # * Create thread in forum.
  #      user.creates_forum_thread(@forum,{:thread => {:subject => 'Flame War!', :contents => 'I B Flamin Yall!'}})
  #
  # = Update
  # Just like <tt>create</tt> but uses <tt>update</tt> prefix, checks the form on the <tt>edit</tt> page instead,
  # and looks for a hidden input with a name of <tt>_method</tt> and a value of <tt>put</tt> in the form.
  # === Sample
  # * <tt>user.updates_article(@article,{:article => {:subject => 'New Subject'}})</tt>
  #
  # = Destroy
  # Use the <tt>deletes</tt> prefix followed by the appropriate path helper.
  # === Arguments
  # Requires ActiveRecord objects or Integers representing id's suitable for passing to path methods,
  # followed by an optional hash containing...
  # * <tt>:via_ajax</tt> -- Set to <b>true</b> to perform <tt>xml_http_request</tt>
  #   instead of standard <tt>http</tt> request. (Default: false).
  # * <tt>:expected_response</tt> -- See <tt>assert_response</tt> in Rails API for list of availble options.
  #   (Default: :redirect).  If <tt>:expected_response => :redirect</tt> and no block is given, will
  #   follow redirect and assert :success.
  # * <tt>:headers</tt> -- A hash of additional or alternate HTTP Headers to pass with the DELETE. See <b>Show</b> above for sample.
  # === Assertions
  # * Response is a redirect, unless <tt>:expected_response</tt> option provided with otherwise.
  # === Samples
  # * <tt>user.deletes_ticket(1)</tt>
  # * <tt>user.deletes_post(@post,{:expected_response => :success}) {|page| page.assert_select :flash_warning, 'Permission Denied' }</tt>
  # * <tt>user.deletes_comment(@comment,{:via_ajax => true}) {|page| page.assert_select_rjs :replace_html, 'feedback' }</tt>
  #
  # = Exercise
  # This test is usually only useful on the most basic controllers, ie, scaffold generated and mostly unedited. But for those
  # controllers, it's a quick easy way to test the whole shebang. It will walk through the entire process of creating, updating,
  # and destroying an object.
  # === Arguments
  # * <tt>new_params</tt> -- Params to use with the <tt>new</tt> and <tt>create</tt> actions.
  # * <tt>update_params</tt> -- Params to use with the <tt>edit</tt> and <tt>update</tt> actions.
  # * Options Hash
  #   * <tt>:expected_not_found_response</tt> -- Defailt is HTTP 404.
  # === Samples
  # * <tt>user.exercises_articles({:article => {:title => 'Excercise if Good', :content => 'New study proves it.'}},{:article => {:subject => 'Exercise is Bad'}})</tt> 
  # 
  module SessionMethods
    
    # See above documentation for SessionMethods
    def method_missing( method_sym, *args, &block ) #:nodoc:
      if method_sym.to_s =~ /^(creates|reads|updates|deletes|exercises)_(.*)/
        self.send($1.to_sym,$2.to_sym,*args,&block)
      else
        super
      end
    end
    
    # Resort to this only when unable to use magic methods described above.
    # 
    # === Samples
    # * <tt>user.reads(:article_comments,@article)</tt>
    # * <tt>user.reads(:comment,@comment,{:via_ajax => true})</tt>
    def reads(object,*args,&block)
      opts = args.last.is_a?(Hash) ? args.pop : {}
      goes_to(path_for(object,args),opts,&block)
    end
    
    # Resort to this only when unable to use magic methods described above.
    # 
    # === Sample
    # * <tt>user.creates(:forum_post,@forum,{:post => {:title => 'X', :body => 'Y'}})</tt>
    def creates(object,*args,&block)
      ids = []
      ids << args.shift until args.first.is_a?(Hash)
      ids = nil if ids.empty?
      params = args.shift
      opts = args.shift || {}
      goes_to(new_path_for(object,ids)) do |page|
        check_form_on(page,self.send("#{object.to_s.pluralize}_path"),:post,params,opts)
      end
      posts_to(path_for(object.to_s.pluralize),params,opts,&block)
    end
    
    # Resort to this only when unable to use magic methods described above.
    # 
    # === Sample
    # * <tt>user.updates(:forum_post,@forum,@post,{:post => {:title => 'Z'}})</tt>
    def updates(object,*args,&block)
      ids = []
      ids << args.shift until args.first.is_a?(Hash)
      ids = nil if ids.empty?
      params = args.shift
      opts = args.shift || {}
      goes_to(edit_path_for(object,ids)) do |page|
        check_form_on(page,self.send("#{object.to_s}_path",*ids),:put,params,opts)
      end
      puts_to(path_for(object,ids),params,opts,&block)
    end
    
    # Resort to this only when unable to use magic methods described above.
    # 
    # === Sample
    # * <tt>user.deletes(:post,@post)</tt>
    def deletes(object,*args,&block)
      ids = []
      ids << args.shift until args.empty? or args.first.is_a?(Hash) 
      ids = nil if ids.empty?
      opts = args.shift || {}
      deletes_to(path_for(object,ids),opts,&block)
    end
    
    # Resort to this only when unable to use magic methods described above.
    # 
    def exercises(object,new_params,update_params,opts={}) #:nodoc:
      id = nil #initialize
      
      #Create
      creates(object,new_params) do |page|
        id = get_id_from_url(page.response.redirected_to)
        page.follow_redirect!
        page.assert_response :success
      end
      
      #Read
      reads(object,id) do |page|
        assert_equal(id,page.assigns(object).id)
      end
      
      #Update
      updates(object,id,update_params) do |page|
        di = get_id_from_url(page.response.redirected_to)
        assert_equal(id,di)
        page.follow_redirect!
        page.assert_response :success
      end
      
      #Destroy
      deletes(object,id)
      reads(object,id,{:expected_response => opts[:expected_not_found_response] || 404})
    end
    
    
    # Resort to this only when unable to use the 'reads' method or the magic methods described above.
    # 
    def goes_to(path,opts={},&block) #:nodoc: 
      opts.reverse_merge!({:expected_response => :success})
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
        opts.reverse_merge!({:expected_response => :success})
        self.send(:xhr,method,path,params,opts[:headers])
      else 
        opts.reverse_merge!({:expected_response => :redirect})
        self.send(method,path,params,opts[:headers])
      end
      assert_response(opts[:expected_response],
        "#{'AJAX ' if opts[:via_ajax]}Failed to get #{opts[:expected_response]} on #{method} to #{path}.")
      #let block follow it's own redirects if it so desires
      if block_given?
        yield self 
      elsif opts[:expected_response] == :redirect    
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
      path = "#{object.to_s}_path"
      if ids.blank?
        self.send(path)
      elsif ids.is_a?(Array)
        self.send(path,*ids)
      else
        self.send(path,ids)
      end
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