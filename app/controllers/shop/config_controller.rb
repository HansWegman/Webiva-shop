
class Shop::ConfigController < ModuleController
  
  permit 'shop_manager'

  component_info 'shop'

  
  public

  def index
     cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], "Configuration" ], "content"
     
  end

   include ActiveTable::Controller
   active_table :region_table,
                Shop::ShopRegion,
                [ ActiveTable::IconHeader.new('',:width => '15'),
                  ActiveTable::StringHeader.new('name', :width => 300),
                  ActiveTable::NumberHeader.new('tax',:width=> 50),
                  ActiveTable::StaticHeader.new('Subregions',:width => 50),
                  ActiveTable::StaticHeader.new('Countries'),
                ]

  def display_region_table(display=true)

     active_table_action('region') do |act,region_ids|
      case act
      when 'delete':
        Shop::ShopRegion.destroy(region_ids)
      end
    end

    @active_table_output = region_table_generate params, {:order => 'name', :include => :countries }


    render :partial => 'region_table' if display
  end

  def regions
     cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], 
                     ["Configuration",url_for(:controller => '/shop/config') ],"Regions" ], "content"

    display_region_table(false)
  end

  def region
     @region = Shop::ShopRegion.find_by_id(params[:path][0]) || Shop::ShopRegion.new
  
     cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], 
                     ["Configuration",url_for(:controller => '/shop/config') ],
                     ["Regions",url_for(:action => 'index') ],
                       @region.id ? ["Edit %s",nil,@region.name] :  "Create Region" ], "content"
    
     if request.post? && params[:region]
        countries = params[:region].delete(:countries).to_s.strip.split("|")
        country = params[:region].delete(:country)

        if !params[:region][:has_subregions] == '0'
          params[:region].delete(:country)
        end

        
        @region.attributes = params[:region]
        @region.valid?

        if params[:region][:has_subregions] == '1'
          @region.errors.add(:country,"is blank") if country.blank?
          countries = [ country  ]
        else 
          @region.errors.add(:countries,"must include at least one value") if countries.blank?
        end

        
        Shop::ShopRegionCountry.find(:all,:conditions => [ "country IN(?) AND shop_region_id != ?",countries,@region.id]).each do |existing_country|
          @region.errors.add(:countries,"can only be in one region: please remove " + existing_country.country)
          @region.errors.add(:country,"can only be in one region: please remove " + existing_country.country)
        end
        

        if(@region.errors.empty?)
          @region.save
          @region.countries.clear
          countries.each do |country|
            @region.countries.create(:country => country) unless country.blank?
          end 
          redirect_to :action => 'regions'
        end 
        
     end
    
  end

   active_table :subregions_table,
                Shop::ShopSubregion,
                [ ActiveTable::IconHeader.new('',:width => '15'),
                  ActiveTable::StringHeader.new('name', :width => 300),
                  ActiveTable::StringHeader.new('abr', :label => 'Abbreviation'),
                  ActiveTable::NumberHeader.new('tax',:width=> 50)
                ]

  def display_subregions_table(display=true)

     @region = Shop::ShopRegion.find(params[:path][0]) unless @region

     active_table_action('subregion') do |act,subregion_ids|
      case act
      when 'delete':
        @region.subregions.destroy(subregion_ids)
      end
    end
    if params[:subregion_create] && request.post?
      @created_region = @region.subregions.create(params[:subregion_create])
    end

    @active_table_output = subregions_table_generate params, {:order => 'name' }


    render :partial => 'subregions_table' if display
  end

  def subregions

      @region = Shop::ShopRegion.find(params[:path][0])

     cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], 
                     ["Configuration",url_for(:controller => '/shop/config') ],
                     ["Regions",url_for(:action => 'regions') ],
                     ["%s Subregions",nil,@region.name] ], 'content'

    display_subregions_table(false)
  end


 include ActiveTable::Controller
   active_table :carrier_table,
                Shop::ShopCarrier,
                [ ActiveTable::IconHeader.new('',:width => '15'),
                  ActiveTable::StringHeader.new('name', :width => 300),
                  ActiveTable::StaticHeader.new('carrier_processor', :label => 'Type')
                ]

  def display_carriers_table(display=true)


     active_table_action('carrier') do |act,carrier_ids|
      case act
      when 'delete':
        Shop::ShopCarrier.destroy(carrier_ids)
      end
    end

    @active_table_output = carrier_table_generate params, {:order => 'name' }


    render :partial => 'carriers_table' if display
  end

  def carriers


     cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], 
                     ["Configuration",url_for(:controller => '/shop/config') ],
                     "Delivery Carriers" ], 'content'

    display_carriers_table(false)
  end


  def carrier

     @handlers = carrier_handlers

     @carrier = Shop::ShopCarrier.find_by_id(params[:path][0]) || Shop::ShopCarrier.new

     cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], 
                     ["Configuration",url_for(:controller => '/shop/config') ],
                     ["Carriers",url_for(:action => 'carriers') ],
                     @carrier.new_record? ? "Create Carrier" : "Edit #{@carrier.name}" ], 'content'

    if request.post? && params[:carrier]
      processor = params[:carrier].delete(:carrier_processor)
      @carrier.carrier_processor = processor if @handlers.detect { |handler| handler[1] == processor }

      if @carrier.update_attributes(params[:carrier])
        redirect_to :action => "carriers"
      end
    end

  end

  protected

  def carrier_handlers
      processors = get_handler_options(:shop,:carrier_processor)
  end
  
  public 
  
   active_table :shipping_table,
                Shop::ShopShippingCategory,
                [ ActiveTable::IconHeader.new('',:width => '15'),
                  ActiveTable::StringHeader.new('shop_shipping_categories.name', :label => 'Name', :width => 300),
                  ActiveTable::StringHeader.new('shop_regions.name', :label => 'Region'),
                  ActiveTable::StringHeader.new('shop_carriers.name', :label => 'Carrier'),
                  ActiveTable::StaticHeader.new('carrier_processor', :label => 'Type')
                ]

  def display_shipping_table(display=true)


     active_table_action('shipping_category') do |act,cat_ids|
      case act
      when 'delete':
        Shop::ShopShippingCategory.destroy(cat_ids)
      end
    end

    @active_table_output = shipping_table_generate params, {:order => 'shop_shipping_categories.name', :include => [:region, :carrier] }


    render :partial => 'shipping_table' if display
  end

  def shipping


     cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], 
                     ["Configuration",url_for(:controller => '/shop/config') ],
                     "Shipping Categories" ], 'content'

    display_shipping_table(false)
  end

  def shipping_category
  
      @shipping_category = Shop::ShopShippingCategory.find_by_id(params[:path][0]) || Shop::ShopShippingCategory.new
       cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], 
                     ["Configuration",url_for(:controller => '/shop/config') ],
                     ["Shipping Categories",url_for(:action => 'shipping')],
                     @shipping_category.new_record? ? 'Create Category' : ['Edit %s',nil,@shipping_category.name] ], 'content'

    @shipping_category.attributes = params[:shipping_category] if params[:shipping_category]
     
    set_shipping_options
    
    if request.post? && params[:shipping_category]
      @processor.validate_options(@category_options)
      
      @shipping_category.valid?
      if @category_options && @category_options.errors.length == 0 && @shipping_category.errors.length == 0
        @shipping_category.options= @category_options.to_h
        if @shipping_category.save
          redirect_to :action => "shipping"
          return
        end
      end
    end
    
    @regions =  [['--Please Select Region--'.t,'']] + Shop::ShopRegion.find_select_options(:all,:order => :name)
    @carriers = [['--Please Select Carrier--'.t,'']] + Shop::ShopCarrier.find_select_options(:all,:order =>:name)

  end
  
  def update_shipping_options
  
    @shipping_category = Shop::ShopShippingCategory.find_by_id(params[:path][0]) || Shop::ShopShippingCategory.new
    @shipping_category.shop_carrier_id = params[:carrier_id]
    
    set_shipping_options
    
    render :partial => 'shipping_category_options'
  end
  
  

  protected
  
  def set_shipping_options

    if @shipping_category.carrier
      @processor = @shipping_category.carrier.processor
      
      @category_options = @processor.get_options(params[:category_options] || @shipping_category.options || {})
    end
  end
  
  public
  
  
   active_table :payment_processor_table,
                Shop::ShopPaymentProcessor,
                [ ActiveTable::IconHeader.new('',:width => '15'),
                  ActiveTable::StringHeader.new('name', :label => 'Name', :width => 300),
                  ActiveTable::StaticHeader.new('currency', :label => 'Currency', :width => 100),
                  ActiveTable::StaticHeader.new('payment_type', :label => 'Payment Type'),
                  ActiveTable::StaticHeader.new('payment_processor', :label => 'Processor')
                ]

  def display_payment_processor_table(display=true)


     active_table_action('payment_processor') do |act,processor_ids|
      case act
      when 'delete':
        Shop::ShopPaymentProcessor.destroy(processor_ids)
      end
    end

    @active_table_output = payment_processor_table_generate params, {:order => 'shop_payment_processors.name' }


    render :partial => 'payment_processor_table' if display
  end

  def payment


     cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], 
                     ["Configuration",url_for(:controller => '/shop/config') ],
                     "Payment Processors" ], 'content'

    display_payment_processor_table(false)
  end
  
  
  def processor
      @processor = Shop::ShopPaymentProcessor.find_by_id(params[:path][0]) || Shop::ShopPaymentProcessor.new
  
     cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], 
                     ["Configuration",url_for(:controller => '/shop/config') ],
                     ["Payment Processors",url_for(:action => 'payment') ],
                     @processor.new_record? ? 'Create Processor' : [ "Edit %s",nil,@processor.name ] ], 'content'

      currency = @mod.options[:shop_currency] || 'USD'
  
      @processor.attributes = params[:processor] if params[:processor]
      @processor.currency = currency if !@processor.currency
      
      @currencies = [  [ currency, currency ] ]
      
      @payment_processors = get_handler_info(:shop,:payment_processor)
      
      @payment_types = [ ['--Select Payment Type--',''] ] + @payment_processors.collect do |handler|
        [ handler[:type].t,handler[:type] ]
      end
      @payment_types.uniq!
      
      @processor.processor_handler = params[:processor][:processor_handler] if params[:processor] && params[:processor][:processor_handler]
      
      if @processor.payment_type
        @available_processors = [ ['--Select Payment Processor-- ',''] ] + @payment_processors.find_all { |info|
          (!info[:currencies] || info[:currencies].include?(@processor.currency)) && info[:type] == @processor.payment_type
        }.collect { |info| [ info[:name], info[:class_name].underscore ] }
      else
        @processor.processor_handler = ''
      end
      
      if @processor.processor_handler &&  # if we have a processor
         @payment_processors.detect { |info|  info[:class_name].underscore == @processor.processor_handler } && # and it's a valid processor
         @processor.processor_handler_class.shop_payment_processor_handler_info[:type] == @processor.payment_type ## and it's the right payment type
        @options = @processor.processor_handler_class.get_options(params[:options] || @processor.options)      
      else
        @processor.processor_handler = nil
      end
      
      
      # Find available 
      if request.xhr? 
        render :partial => 'processor_form'
        return 
      elsif request.post?
        if @processor.valid? && @processor.processor_handler_class.validate_options(@options)
          @processor.options = @options.to_h
          @processor.save
          redirect_to :action => 'payment'
          return 
        end
      end
      
      
  end
  

end
