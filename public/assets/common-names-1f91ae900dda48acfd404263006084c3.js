function vet_common_name(t,e,i,n,s){var o=document.getElementById(n).selectedIndex,r=document.getElementById(n).options;document.getElementById("form_taxon_concept_id").value=t,document.getElementById("form_language_id").value=e,document.getElementById("form_name_id").value=i,document.getElementById("form_vetted_id").value=r[o].value,document.getElementById("form_hierarchy_entry_id").value=s,document.forms.vet_common_name_form.submit()}if(!EOL)var EOL={};EOL.init_common_name_behaviors||(EOL.init_common_name_behaviors=function(){$('td.preferred_name_selector input[type="radio"]').unbind("click"),$('td.preferred_name_selector input[type="radio"]').on("click",function(){var t=$(this).closest("form");t.submit()}),$("td.vet_common_name select").unbind("change").change(function(){var t=$(this).closest("tr"),e=$(this).attr("data_url");e=e.replace(/REPLACE_ME/,$(this).val()),EOL.ajax_submit($(this),{url:e,update:t,data:{},type:"GET",complete:function(){EOL.init_common_name_behaviors()}})}),$("#add_common_name_button").unbind("click"),$("#add_common_name_button").on("click",function(){{var t=$.trim($("#name_name_string").val());$("#name_language").val()}""!==t?(i_agree=confirm("Create a new common name?\n\nYou can always delete it later"),i_agree&&$(this).closest("form").submit()):alert("Add a new common name first")})}),$(document).ready(function(){EOL.init_common_name_behaviors()});