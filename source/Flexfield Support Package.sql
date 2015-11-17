                       create or replace PACKAGE FLEXFIELD AS 

  
  function is_active(p_source_table in varchar2, p_source_column in varchar2) return number;
  function get_name(p_source_table in varchar2, p_source_column in varchar2) return FLEXFIELD_DEF.NAME%type;
  function get_description(p_source_table in varchar2, p_source_column in varchar2) return FLEXFIELD_DEF.DESCRIPTION%type;  
  /*
   * Initializes application items with its flexfield name in case it is active.
   * ----------
   * @p_prefix Application item prefix
   * @p_flexfield_prefix Flexfield column name prefix
   *
   * It assumes you have:
   * 1) Table with flexfields defined with naming convention: <FLEXFIELD_PREFIX>_<FLEXFIELD_NUMBER>
   *     Examples: FLEXFIELD_001, FLEXFIELD_002
   * 2) Application items with naming convetion <PREFIX>_<TABLE_NAME>_<FLEXFIELD_NUMBER>
   *    Examples BF_FLEX_FARMACIA_001
   *
   * Example
   * BF_FLEX_FARMACIA_001
   *   - p_prefix BF_FLEX_
   *   - p_flexfield_prefix FLEXFIELD_
   *
   *   -> Sets BF_FLEX_FARMACIA_001 app. item with flexfield name on table FARMACIA, column FLEXFIELD_001
   *           :BF_FLEX_FARMACIA_001 := FLEXFIELD.get_name('FARMACIA','FLEXFIELD_001')
   */
  procedure intialize_application_items(p_prefix in varchar2,p_flexfield_prefix in varchar2);
  
  procedure erase_flexfield(p_source_table in varchar2, p_source_column in varchar2, p_erase_filter in varchar2 default null);
  
  /* Returns display value in case flexfield is  LOV type.
     Detects flexfield type, in case it's not LOV type returns @p_return_value
     Otherwise, searches lookup table display value for @p_return_value 
     
     @p_source_table flexfield source table
     @p_source_column flexfield source column
     @p_return_value value to lookup and return display value
     
     @return display_value
   */
  function lookup_display_value(p_source_table in varchar2, p_source_column in varchar2, p_return_value in varchar2) return varchar2;
END FLEXFIELD;
/
create or replace PACKAGE BODY FLEXFIELD AS 

  
  function is_active(p_source_table in varchar2, p_source_column in varchar2) return number
  is 
    v_res int;
  begin
    
    select count(1) into v_res
      from flexfield_def
     where source_table = p_source_table and source_column = p_source_column and active = 'S';
    
    return v_res; 
  end is_active;
  function get_name(p_source_table in varchar2, p_source_column in varchar2) return FLEXFIELD_DEF.NAME%type
  is
    v_aux FLEXFIELD_DEF.NAME%type;
  begin
    select name into v_aux
      from flexfield_def
     where source_table = p_source_table and source_column = p_source_column and active = 'S';
     
     return v_aux;
  exception when no_data_found then return null;
  end get_name;
  
  function get_description(p_source_table in varchar2, p_source_column in varchar2) return FLEXFIELD_DEF.DESCRIPTION%type
  is
      v_aux FLEXFIELD_DEF.DESCRIPTION%type;
  begin
    select name into v_aux
      from flexfield_def
     where source_table = p_source_table and source_column = p_source_column and active = 'S';
     
     return v_aux;
  exception when no_data_found then return null;
  end get_description;
  
  procedure intialize_application_items(p_prefix in varchar2,p_flexfield_prefix in varchar2) is
  begin
   
    for c in (select item_name,
                     substr(item_name,length(p_prefix)+1,length(item_name)-length(p_prefix)-4) SOURCE_TABLE,
                     p_flexfield_prefix||substr(item_name,-3) SOURCE_COLUMN
                from apex_application_items where application_id = v('APP_ID')
                 and item_name like p_prefix||'%') loop
                 
   
      APEX_UTIL.set_session_state(
        p_name => c.item_name
        , p_value => FLEXFIELD.get_name(p_source_table=>c.source_table,p_source_column => c.source_column));
    end loop;

  end intialize_application_items;
  
  
  procedure erase_flexfield(p_source_table in varchar2, p_source_column in varchar2, p_erase_filter in varchar2 default null)
  is
    v_sql varchar2(4000);
  begin
    if (p_source_table is not null and p_source_column is not null) then
    
      v_sql := 'UPDATE '||p_source_table||' SET '||p_source_column||' = null';      
      
      if (p_erase_filter is not null) then
         v_sql := v_sql||' WHERE ('||p_erase_filter||')';
      end if;
      
      
      execute immediate v_sql;
      
      update flexfield_def set name = '<FLEXFIELD LIBRE>', description=null,type='STRING',lov=null, active='N'
      where source_column = p_source_column and source_table = p_source_table;
    end if;
  end erase_flexfield;
  
  function lookup_display_value(p_source_table in varchar2, p_source_column in varchar2, p_return_value in varchar2) return varchar2
  is
    v_type flexfield_def.type%type;
    v_lov_type apex_application_lovs.lov_type%type;
    v_lov flexfield_def.lov%type;
    v_res APEX_APPLICATION_LOV_ENTRIES.return_value%type;
    v_sql apex_application_lovs.list_of_values_query%type;
    
    TYPE itemRec is record (disp APEX_APPLICATION_LOV_ENTRIES.display_value%type,ret APEX_APPLICATION_LOV_ENTRIES.return_value%type);
    TYPE itemSet is table of itemRec;
    v_selected varchar2(2000);
    v_options itemSet;
  begin
    select type,lov,lov_sql into v_type,v_lov,v_sql
      from flexfield_def
     where source_table = p_source_table and source_column = p_source_column and active = 'S';
    
    if v_type='LOV' then
      
      select lov_type into v_lov_type 
        from apex_application_lovs
       where list_of_values_name = v_lov  and application_id = v('APP_ID') and rownum <2; 
      if (v_lov_type = 'Static') then
        select display_value into v_res
          from APEX_APPLICATION_LOV_ENTRIES
         where list_of_values_name = v_lov 
              and application_id = v('APP_ID')  
              and return_value = p_return_value;
      else
        select list_of_values_query into v_sql
          from apex_application_lovs
         where list_of_values_name = v_lov and application_id = v('APP_ID') and rownum <2;
         
         EXECUTE IMMEDIATE v_sql
             BULK COLLECT INTO v_options;
          for i in v_options.FIRST..v_options.LAST
          loop
            if (p_return_value = v_options(i).ret) then 
              v_res := v_options(i).disp;
              return v_res;
            end if;            
          end loop;
          
      end if;
    elsif (v_type ='LOVSQL') then
      EXECUTE IMMEDIATE v_sql
         BULK COLLECT INTO v_options;
      for i in v_options.FIRST..v_options.LAST
      loop
        if (p_return_value = v_options(i).ret) then 
          v_res := v_options(i).disp;
          return v_res;
        end if;            
      end loop;
    end if;
    return nvl(v_res,p_return_value);
  exception when others then return p_return_value;   
  end lookup_display_value;

END FLEXFIELD;

/