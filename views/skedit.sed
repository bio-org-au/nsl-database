s/{"data"://

s/"bdr_context_v":\[/"@context":/ 
s/\],"bdr_graph_v":\[/,"@graph":[/ 
s/"apni_bdr_context_v":\[/"@context":/ 
s/\],"apni_bdr_graph_v":\[/,"@graph":[/ 

s/{"bdr_sdo":\[// 
s/\],"bdr_labels":\[/,/ 
s/\],"bdr_tree_schema":\[/,/
s/\],"bdr_schema":\[/,/

s/\],"bdr_top_concept":\[/,/ 
s/\],"bdr_concepts":\[/,/ 
s/\],"bdr_alt_labels":\[/,/ 
s/\],"bdr_unplaced":\[/,/ 

s/"boa__cites":\[{//ig
s/"boa:cites":\[{//ig
s/}}, *{"boa:/},"boa:/g
s/}}\]},/}},/g
# s/,"boa__cites":null//g 
# s/,"boa:cites":null//g 

s/"_id"/"@id"/g
s/"_type"/"@type"/g
s/__/:/g
# s/"[^"]*":null,//g
s/\]}\]}$/]}/
s/\]}\]}}$/]}/

s/boa__\([a-z]*Label\)/boa:\1/
