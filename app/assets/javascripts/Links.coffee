

class MaskLink extends Backbone.View
  
  initialize: (pass) =>
    _.bindAll @
    
    @aspects = pass.aspects
    @inner   = pass.inner
    @from    = pass.from
    @to      = pass.to
    
  render: =>
    @inputs = { }
    
    for from in npc_data.aspects[@from].values
      opt = @option(from)
    
  
  option: (name) =>
    tab = fromString """<table></table>"""
    opt = fromString """
      <div class="aspect">
        <p class="name">#{name}</p>
      </div>
    """
    
    opt.append(tab)
    
    inputs = { }
    
    for to in npc_data.aspects[@to].values
      newInput = fromString """
        <input type="text" class="linkValue" value="#{to[1]}">
      """
      
      inputs[to[0]] = newInput
      
      row = fromString """
        <tr>
          <td><div class="linkName">#{to[0]}</div></td>
        </tr>
      """
      col = fromString "<td></td>"
      
      col.append(newInput)
      row.append(col)
      tab.append(row)
      
    @inputs[from[0]] = inputs
    
    opt





