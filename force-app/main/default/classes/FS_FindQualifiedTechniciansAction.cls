/**
 * Agentforce action: finds technicians (Service Resources) with a given skill, optionally in a given territory.
 * Input: skillName (required, e.g. "TV Repair"), territoryName (optional, e.g. "Guntur").
 * Output: one TechnicianMatch row per qualified, active technician, capped at 10.
 */
public with sharing class FS_FindQualifiedTechniciansAction {

    public class Request {
        @InvocableVariable(required=true label='Required Skill' description='e.g. TV Repair, AC Repair, Refrigerator Repair, Installation.')
        public String skillName;
        @InvocableVariable(label='Territory' description='Optional. e.g. Guntur, Vijayawada, Visakhapatnam, Tirupati, Hyderabad.')
        public String territoryName;
    }

    public class TechnicianMatch {
        @InvocableVariable public String technicianName;
        @InvocableVariable public String territory;
        @InvocableVariable public String skills;
    }

    public class Result {
        @InvocableVariable(label='Technicians')
        public List<TechnicianMatch> technicians = new List<TechnicianMatch>();
    }

    @InvocableMethod(
        label='Find Qualified Technicians'
        description='Returns active technicians who have a given skill, optionally scoped to a territory.'
        category='Field Service'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            List<TechnicianMatch> rows = res.technicians;
            try {
                if (String.isNotBlank(r.skillName)) {
                    Set<Id> resourceIds = new Set<Id>();
                    for (ServiceResourceSkill srs : [
                        SELECT ServiceResourceId FROM ServiceResourceSkill
                        WHERE Skill.MasterLabel = :r.skillName WITH USER_MODE
                    ]) {
                        resourceIds.add(srs.ServiceResourceId);
                    }
                    if (!resourceIds.isEmpty()) {
                        String query = 'SELECT Name, (SELECT Skill.MasterLabel FROM ServiceResourceSkills), ' +
                            '(SELECT ServiceTerritory.Name FROM ServiceTerritories) ' +
                            'FROM ServiceResource WHERE Id IN :resourceIds AND IsActive = true';
                        Map<String, Object> binds = new Map<String, Object>{'resourceIds' => resourceIds};
                        if (String.isNotBlank(r.territoryName)) {
                            query += ' AND Id IN (SELECT ServiceResourceId FROM ServiceTerritoryMember WHERE ServiceTerritory.Name = :territoryName)';
                            binds.put('territoryName', r.territoryName);
                        }
                        query += ' LIMIT 10';
                        for (ServiceResource sres : (List<ServiceResource>) Database.queryWithBinds(query, binds, AccessLevel.USER_MODE)) {
                            TechnicianMatch tm = new TechnicianMatch();
                            tm.technicianName = sres.Name;
                            List<String> skillNames = new List<String>();
                            for (ServiceResourceSkill s : sres.ServiceResourceSkills) skillNames.add(s.Skill.MasterLabel);
                            tm.skills = String.join(skillNames, ', ');
                            List<String> territoryNames = new List<String>();
                            for (ServiceTerritoryMember stm : sres.ServiceTerritories) territoryNames.add(stm.ServiceTerritory.Name);
                            tm.territory = String.join(territoryNames, ', ');
                            rows.add(tm);
                        }
                    }
                }
            } catch (Exception e) {
                // Sanitized: never leak internal error text to the agent/user.
            }
            out.add(res);
        }
        return out;
    }
}