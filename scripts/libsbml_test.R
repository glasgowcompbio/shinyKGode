library(libSBML)

printFunctionDefinition <- function(n, fd) {
    if ( FunctionDefinition_isSetMath(fd) )
    {
        cat("FunctionDefinition ",n,", ",FunctionDefinition_getId(fd),"(");
        
        math = FunctionDefinition_getMath(fd);
        
        # Print function arguments. 
        if (ASTNode_getNumChildren(math) > 1) {
            cat(ASTNode_getName( ASTNode_getLeftChild(math) ));
            
            for (n in seq_len(ASTNode_getNumChildren(math) - 1)) {
                cat(", ", ASTNode_getName( ASTNode_getChild(math, n) ));
            }
        }
        
        cat(") := ");
        
        # Print function body. 
        if (ASTNode_getNumChildren(math) == 0) {
            cat("(no body defined)");
        } else {
            math    = ASTNode_getChild(math, ASTNode_getNumChildren(math) - 1);
            formula = formulaToString(math);
            cat(formula,"\n");      
        }
    }
}


printRuleMath <- function(n, r) {
    if ( Rule_isSetMath(r) ) {
        formula = formulaToString( Rule_getMath(r) );
        cat("Rule ",n,", formula: ",formula,"\n");    
    }
}


printReactionMath <- function(n, r)
{
    if (Reaction_isSetKineticLaw(r)) {
        kl = Reaction_getKineticLaw(r);
        
        if ( KineticLaw_isSetMath(kl) ) {
            formula = formulaToString( KineticLaw_getMath(kl) );
            cat("Reaction ",n,", formula: ",formula,"\n");      
        }
    }
}


printEventAssignmentMath <- function(n, ea) {
    if ( EventAssignment_isSetMath(ea) ) {
        variable = EventAssignment_getVariable(ea);
        formula  = formulaToString( EventAssignment_getMath(ea) );
        
        cat("  EventAssignment ",n,", trigger: ",variable," = ",formula,"\n");
        
    }
}


printEventMath <- function(n, e) {
    if ( Event_isSetDelay(e) ) {
        delay = Event_getDelay(e);
        formula = formulaToString( Delay_getMath(delay) );
        cat("Event ",n," delay: ",formula,"\n");    
    }
    
    if ( Event_isSetTrigger(e) ) {
        trigger = Event_getTrigger(e);
        
        formula = formulaToString( Trigger_getMath(trigger) );
        cat("Event ",n," trigger: ",formula,"\n");    
    }
    
    for (i in seq_len(Event_getNumEventAssignments(e))) {
        printEventAssignmentMath(i, Event_getEventAssignment(e, i-1));
    }
    
    cat("\n");
}


printMath <- function(m) {
    
    for (n in seq_len(Model_getNumFunctionDefinitions(m))){
        printFunctionDefinition(n, Model_getFunctionDefinition(m, n-1));
    }
    
    for (n in seq_len(Model_getNumRules(m))){
        printRuleMath(n , Model_getRule(m, n-1));
    }
    
    cat("\n");
    
    for (n in seq_len(Model_getNumReactions(m))){
        printReactionMath(n, Model_getReaction(m, n-1));
    }
    
    cat("\n");
    
    for (n in seq_len(Model_getNumEvents(m))){
        printEventMath(n , Model_getEvent(m, n-1));
    }
}

filename = 'LotkaVolterra.xml';
d        = readSBML(filename);
errors   = SBMLDocument_getNumErrors(d);
SBMLDocument_printErrors(d);

m = SBMLDocument_getModel(d);

level   = SBase_getLevel  (d);
version = SBase_getVersion(d);

cat("\n");
cat("File: ",filename," (Level ",level,", version ",version,")\n");

if (errors > 0) {
    stop("No model present.");  
}

cat("         ");
cat("  model id: ", ifelse(Model_isSetId(m), Model_getId(m) ,"(empty)"),"\n");

cat( "functionDefinitions: ", Model_getNumFunctionDefinitions(m) ,"\n" );
cat( "    unitDefinitions: ", Model_getNumUnitDefinitions    (m) ,"\n" );
cat( "   compartmentTypes: ", Model_getNumCompartmentTypes   (m) ,"\n" );
cat( "        specieTypes: ", Model_getNumSpeciesTypes       (m) ,"\n" );
cat( "       compartments: ", Model_getNumCompartments       (m) ,"\n" );
cat( "            species: ", Model_getNumSpecies            (m) ,"\n" );
cat( "         parameters: ", Model_getNumParameters         (m) ,"\n" );
cat( " initialAssignments: ", Model_getNumInitialAssignments (m) ,"\n" );
cat( "              rules: ", Model_getNumRules              (m) ,"\n" );
cat( "        constraints: ", Model_getNumConstraints        (m) ,"\n" );
cat( "          reactions: ", Model_getNumReactions          (m) ,"\n" );
cat( "             events: ", Model_getNumEvents             (m) ,"\n" );
cat( "\n" );

params = character(0);
paramsVals = vector();
for(i in seq_len(Model_getNumParameters( m ))) {
    sp = Model_getParameter( m, i-1);
    params = c(params, Parameter_getId(sp));
    paramsVals = c(paramsVals, Parameter_getValue(sp));
}
print(params);
print(paramsVals);

species = character(0);
speciesInitial = vector()
for(i in seq_len(Model_getNumSpecies(m))) {
    sp = Model_getSpecies(m, i-1);
    species = c(species, Species_getId(sp));
    speciesInitial = c(speciesInitial, Species_getInitialConcentration(sp));
}
print(species);
print(speciesInitial);
print(length(species));

printMath(m);
cat("\n");
