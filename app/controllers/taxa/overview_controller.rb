class Taxa::OverviewController < TaxaController

  layout 'taxa'

  before_filter :instantiate_taxon_page,
    :redirect_if_superceded,
    :instantiate_preferred_names,
    :add_page_view_log_entry

  def show
    with_master_if_curator do
      @overview = @taxon_page.overview
      @data = @taxon_page.data
      @overview_data = @data.get_data_for_overview
      @range_data = @data.ranges_for_overview
    end
    @assistive_section_header = I18n.t(:assistive_overview_header)
    @rel_canonical_href = taxon_overview_url(@overview)
    current_user.log_activity(:viewed_taxon_concept_overview, taxon_concept_id: @taxon_concept.id)
  end

end
