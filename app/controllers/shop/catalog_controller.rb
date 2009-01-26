
class Shop::CatalogController < ModuleController
  
  permit 'shop_manage'

  component_info 'Shop'

  cms_admin_paths "content",
                  "Content" => { :controller => '/content' },
                  "Shop" => { :controller => '/shop/manage' },
                  "Catalog" => { :action => 'index' }

  include Shop::ShopBase
  
  public


  # need to include 
   include ActiveTable::Controller   
   active_table :product_table,
                Shop::ShopProduct,
                [ ActiveTable::IconHeader.new('', :width=>10),
                  ActiveTable::StaticHeader.new('Image'),
                  ActiveTable::StringHeader.new('shop_products.internal_sku',:label => 'Sku'),
                  ActiveTable::StringHeader.new('shop_products.name',:label => 'Name'),
                  ActiveTable::StringHeader.new('shop_product_prices.price',:label => 'Price'),
                  ActiveTable::StringHeader.new('shop_product_classes.name',:label => 'Product Class'),
                  ActiveTable::StringHeader.new('shop_categories.name',:label => 'Categories'),
                  ActiveTable::StaticHeader.new('Features')
                ]

  def catalog_table(display=true)
  
    active_table_action('product') do |act,pids|
      case act
      when 'delete':
        Shop::ShopProduct.destroy(pids)
      when 'duplicate':
        Shop::ShopProduct.find(pids).each do |prd|
          prd.copy_product
        end
      end
      DataCache.expire_content("ShopProduct")
    end
    @currency_display = Shop::ShopProductPrice.currency_display
    
    @active_table_output = product_table_generate params, :include => [ :prices, :image_file, :shop_product_class, :shop_category_products, :shop_categories, :shop_product_features ], :order => 'shop_products.name,shop_categories.left_index,shop_categories.name'
    
    render :partial => 'product_table' if display
  end

  def index 
     cms_page_path ["Content","Shop"], "Catalog" 
  
    catalog_table(false)
  end
  
  def edit
    @product = Shop::ShopProduct.find(:first,:conditions => ['id=?',params[:path][0]]) || Shop::ShopProduct.new
 
    cms_page_path ["Content","Shop", "Catalog" ],   @product.id ? [  'Edit %s',nil,@product.name ] : 'Create Product' 
    
    require_js('cms_form_editor.js')
#     @header = "<script src='/javascripts/cms_form_editor.js' type='text/javascript'></script>"

    @product_classes =[['--Select Class--','']] + Shop::ShopProductClass.find_select_options(:all,:order => 'name')
    
    @active_currencies = get_currencies
    @available_features = [['--Select a feature to add--','']] + get_handler_options(:shop,:product_feature)

    @prices = @product.get_prices
    
    if request.post? && params[:product]
      captions= params[:product].delete(:caption)

      @product.set_captions(captions)
      @product.attributes = params[:product]
      

      (params[:prices]||{}).each do |currency,price|
        if price.to_f <= 0.0 || !@active_currencies.include?(currency)
          @price_error = true
        end
        @prices[currency] = price
      end

      # Assign features by putting them in order from the sorted feature_order array
      # Each features options are in a hash indexed by its idx (not id) - as new features don't have any id's       
      @product.features = params[:features_order].split(",").collect { |idx| params[:feature][idx.strip] || {} } if params[:features_order] 
      
      if @product.valid? && !@price_error
        
        @product.save 
        @product.set_prices(params[:prices])
        update_categories(@product) if params[:cat]
        save_product_options(@product)

        DataCache.expire_content("ShopProduct")

        redirect_to :action => 'index'
      end
    end
    
    @product_categories = Shop::ShopCategory.generate_tree(@product.id)
  end
  
  
  def update_options
    @product = Shop::ShopProduct.find_by_id(params[:product_id]) || Shop::ShopProduct.new
    
    @active_currencies = get_currencies
    
    @product_class = Shop::ShopProductClass.find_by_id(params[:product_class_id])
    render :partial => 'options', :locals => { :shop_product_class => @product_class }
  end
  
  def add_feature
    @product = Shop::ShopProduct.find_by_id(params[:product_id]) || Shop::ShopProduct.new
    
    @info = get_handler_info(:shop,:product_feature,params[:feature_handler])
    
    if @info 
      @active_currencies = get_currencies
      @feature = @product.shop_product_features.build()
      @feature.shop_feature_handler = @info[:identifier]
      render :partial => 'feature', :locals => { :feature => @feature, :idx => params[:index] }
    else
      render :nothing => true
    end
  
  end
  

  protected 

  def update_categories(prd) 

    prev_selected = params[:cat][:prev_selected]
    selected = params[:cat][:selected] || {}

    prev_featured = params[:cat][:prev_featured]
    featured = params[:cat][:featured]

    prev_selected.each do |cat_id,cat_prev_selected|
      if(selected[cat_id] && cat_prev_selected == '0')
         prd.add_category(cat_id,featured[cat_id] == '1' ? 1 : 0)
      elsif(!selected[cat_id] && cat_prev_selected == '1')
        prd.remove_category(cat_id)
      elsif(selected[cat_id] && prev_featured[cat_id] != featured[cat_id])
         prd.add_category(cat_id,featured[cat_id] == '1' ? 1 : 0)
      end
    end

  end
  
  def save_product_options(prd)
    options = params[:options] || []
    options.each do |variation_option_id,values|
      
      opt = prd.shop_product_options.find_by_shop_variation_option_id(variation_option_id) ||
            prd.shop_product_options.build(:shop_variation_option_id => variation_option_id)
      values[:prices] ||= {}
      values[:weight] = 0.0 unless values[:override].to_i == 1
      values[:prices] = {} unless values[:override].to_i == 1 || values[:variation_type] == 'quantity'
      
      values.delete(:variation_type)

      decimal_prices  = {}
      values[:prices].each { |currency,price| decimal_prices[currency] = price.to_f }
      values[:prices] = decimal_prices
            
      opt.attributes = values
      opt.save
    end
    
  end

end
