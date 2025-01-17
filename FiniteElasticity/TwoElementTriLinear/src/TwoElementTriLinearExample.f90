!> \file
!> \author Kumar Mithraratne
!> \brief This is an example program to solve a finite elasticity equation using openCMISS calls.
!>
!> \section LICENSE
!>
!> Version: MPL 1.1/GPL 2.0/LGPL 2.1
!>
!> The contents of this file are subject to the Mozilla Public License
!> Version 1.1 (the "License"); you may not use this file except in
!> compliance with the License. You may obtain a copy of the License at
!> http://www.mozilla.org/MPL/
!>
!> Software distributed under the License is distributed on an "AS IS"
!> basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
!> License for the specific language governing rights and limitations
!> under the License.
!>
!> The Original Code is openCMISS
!>
!> The Initial Developer of the Original Code is University of Auckland,
!> Auckland, New Zealand and University of Oxford, Oxford, United
!> Kingdom. Portions created by the University of Auckland and University
!> of Oxford are Copyright (C) 2007 by the University of Auckland and
!> the University of Oxford. All Rights Reserved.
!>
!> Contributor(s): 
!>
!> Alternatively, the contents of this file may be used under the terms of
!> either the GNU General Public License Version 2 or later (the "GPL"), or
!> the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
!> in which case the provisions of the GPL or the LGPL are applicable instead
!> of those above. If you wish to allow use of your version of this file only
!> under the terms of either the GPL or the LGPL, and not to allow others to
!> use your version of this file under the terms of the MPL, indicate your
!> decision by deleting the provisions above and replace them with the notice
!> and other provisions required by the GPL or the LGPL. If you do not delete
!> the provisions above, a recipient may use your version of this file under
!> the terms of any one of the MPL, the GPL or the LGPL.
!>

!> \example FiniteElasticity/TwoElementTriLinear/src/TwoElementTriLinearExample.f90
!! Example program to solve a finite elasticity equation using openCMISS calls.
!! \par Latest Builds:
!! \li <a href='http://autotest.bioeng.auckland.ac.nz/opencmiss-build/logs_x86_64-linux/FiniteElasticity/TwoElementTriLinear/build-intel'>Linux Intel Build</a>
!! \li <a href='http://autotest.bioeng.auckland.ac.nz/opencmiss-build/logs_x86_64-linux/FiniteElasticity/TwoElementTriLinear/build-gnu'>Linux GNU Build</a>
!<

!> Main program
PROGRAM TWOELEMENTTRILINEAR

  USE BASE_ROUTINES   
  USE BASIS_ROUTINES   
  USE BOUNDARY_CONDITIONS_ROUTINES   
  USE CMISS   
  USE CMISS_MPI    
  USE CMISS_PETSC   
  USE COMP_ENVIRONMENT   
  USE CONSTANTS    
  USE CONTROL_LOOP_ROUTINES   
  USE COORDINATE_ROUTINES   
  USE DISTRIBUTED_MATRIX_VECTOR    
  USE DOMAIN_MAPPINGS   
  USE EQUATIONS_ROUTINES   
  USE EQUATIONS_SET_CONSTANTS   
  USE EQUATIONS_SET_ROUTINES   
  USE FIELD_ROUTINES   
  USE FIELD_IO_ROUTINES 
  USE GENERATED_MESH_ROUTINES   
  USE INPUT_OUTPUT   
  USE ISO_VARYING_STRING   
  USE KINDS   
  USE LISTS   
  USE MESH_ROUTINES   
  USE MPI   
  USE NODE_ROUTINES     
  USE PROBLEM_CONSTANTS    
  USE PROBLEM_ROUTINES   
  USE REGION_ROUTINES   
  USE SOLVER_ROUTINES   
  USE TIMER   
  USE TYPES

#ifdef WIN32
  USE IFQWIN
#endif

  IMPLICIT NONE

  !Test program parameters

  REAL(DP), PARAMETER :: HEIGHT=1.0_DP
  REAL(DP), PARAMETER :: WIDTH=1.0_DP
  REAL(DP), PARAMETER :: LENGTH=1.0_DP

  !Program types


  !Program variables

  INTEGER(INTG) :: NUMBER_GLOBAL_X_ELEMENTS,NUMBER_GLOBAL_Y_ELEMENTS,NUMBER_GLOBAL_Z_ELEMENTS
  INTEGER(INTG) :: NUMBER_COMPUTATIONAL_NODES,NUMBER_OF_DOMAINS,MY_COMPUTATIONAL_NODE_NUMBER,MPI_IERROR
  INTEGER(INTG) :: EQUATIONS_SET_INDEX  
  INTEGER(INTG) :: first_global_dof,first_local_dof,first_local_rank,last_global_dof,last_local_dof,last_local_rank,rank_idx

  TYPE(BASIS_TYPE), POINTER :: BASIS
  TYPE(BOUNDARY_CONDITIONS_TYPE), POINTER :: BOUNDARY_CONDITIONS
  TYPE(COORDINATE_SYSTEM_TYPE), POINTER :: COORDINATE_SYSTEM
  TYPE(MESH_TYPE), POINTER :: MESH
  TYPE(DECOMPOSITION_TYPE), POINTER :: DECOMPOSITION
  TYPE(EQUATIONS_TYPE), POINTER :: EQUATIONS
  TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET
  TYPE(FIELD_TYPE), POINTER :: GEOMETRIC_FIELD,FIBRE_FIELD,MATERIAL_FIELD,DEPENDENT_FIELD
  TYPE(PROBLEM_TYPE), POINTER :: PROBLEM
  TYPE(REGION_TYPE), POINTER :: REGION,WORLD_REGION
  TYPE(SOLVER_TYPE), POINTER :: SOLVER,LINEAR_SOLVER
  TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: SOLVER_EQUATIONS
  TYPE(NODES_TYPE), POINTER :: NODES
  TYPE(MESH_ELEMENTS_TYPE), POINTER :: ELEMENTS

  LOGICAL :: EXPORT_FIELD,IMPORT_FIELD
  TYPE(VARYING_STRING) :: FILE,METHOD

  REAL(SP) :: START_USER_TIME(1),STOP_USER_TIME(1),START_SYSTEM_TIME(1),STOP_SYSTEM_TIME(1)

#ifdef WIN32
  !Quickwin type
  LOGICAL :: QUICKWIN_STATUS=.FALSE.
  TYPE(WINDOWCONFIG) :: QUICKWIN_WINDOW_CONFIG
#endif

  !Generic CMISS variables
  INTEGER(INTG) :: ERR
  TYPE(VARYING_STRING) :: ERROR
  INTEGER(INTG) :: DIAG_LEVEL_LIST(5)
  CHARACTER(LEN=MAXSTRLEN) :: DIAG_ROUTINE_LIST(1),TIMING_ROUTINE_LIST(1)

  !local variables
  INTEGER(INTG) :: coordinate_system_user_number,number_of_spatial_coordinates
  INTEGER(INTG) :: region_user_number
  INTEGER(INTG) :: basis_user_number,number_of_xi_coordinates  
  INTEGER(INTG) :: total_number_of_nodes,node_idx,global_node_number  
  INTEGER(INTG) :: mesh_user_number,number_of_mesh_dimensions,number_of_mesh_components
  INTEGER(INTG) :: total_number_of_elements,mesh_component_number
  INTEGER(INTG) :: decomposition_user_number  
  INTEGER(INTG) :: field_geomtery_user_number,field_geometry_number_of_varaiables,field_geometry_number_of_components  
  INTEGER(INTG) :: field_fibre_user_number,field_fibre_number_of_varaiables,field_fibre_number_of_components 
  INTEGER(INTG) :: field_material_user_number,field_material_number_of_varaiables,field_material_number_of_components 
  INTEGER(INTG) :: field_dependent_user_number,field_dependent_number_of_varaiables,field_dependent_number_of_components 
  INTEGER(INTG) :: equation_set_user_number
  INTEGER(INTG) :: problem_user_number     
  INTEGER(INTG) :: dof_idx,number_of_global_dependent_dofs,number_of_global_geometric_dofs  
  REAL(DP), POINTER :: FIELD_DATA(:)

#ifdef WIN32
  !Initialise QuickWin
  QUICKWIN_WINDOW_CONFIG%TITLE="General Output" !Window title
  QUICKWIN_WINDOW_CONFIG%NUMTEXTROWS=-1 !Max possible number of rows
  QUICKWIN_WINDOW_CONFIG%MODE=QWIN$SCROLLDOWN
  !Set the window parameters
  QUICKWIN_STATUS=SETWINDOWCONFIG(QUICKWIN_WINDOW_CONFIG)
  !If attempt fails set with system estimated values
  IF(.NOT.QUICKWIN_STATUS) QUICKWIN_STATUS=SETWINDOWCONFIG(QUICKWIN_WINDOW_CONFIG)
#endif

  !Intialise cmiss
  NULLIFY(WORLD_REGION)
  CALL CMISS_INITIALISE(WORLD_REGION,ERR,ERROR,*999)

  CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"*** PROGRAM STARTING ********************",ERR,ERROR,*999)

  !Set all diganostic levels on for testing
  DIAG_LEVEL_LIST(1)=1
  DIAG_LEVEL_LIST(2)=2
  DIAG_LEVEL_LIST(3)=3
  DIAG_LEVEL_LIST(4)=4
  DIAG_LEVEL_LIST(5)=5

  TIMING_ROUTINE_LIST(1)="PROBLEM_FINITE_ELEMENT_CALCULATE"

  !Calculate the start times
  CALL CPU_TIMER(USER_CPU,START_USER_TIME,ERR,ERROR,*999)
  CALL CPU_TIMER(SYSTEM_CPU,START_SYSTEM_TIME,ERR,ERROR,*999)

  !Get the number of computational nodes
  NUMBER_COMPUTATIONAL_NODES=COMPUTATIONAL_NODES_NUMBER_GET(ERR,ERROR)
  IF(ERR/=0) GOTO 999
  !Get my computational node number
  MY_COMPUTATIONAL_NODE_NUMBER=COMPUTATIONAL_NODE_NUMBER_GET(ERR,ERROR)
  IF(ERR/=0) GOTO 999

  !Read in the number of elements in the X,Y and Z directions, and the number of partitions on the master node (number 0)
  !IF(MY_COMPUTATIONAL_NODE_NUMBER==0) THEN
  !  WRITE(*,'("Enter the number of elements in the X direction :")')
  !  READ(*,*) number_global_x_elements
  !  WRITE(*,'("Enter the number of elements in the Y direction :")')
  !  READ(*,*) number_global_y_elements
  !  WRITE(*,'("Enter the number of elements in the Z direction :")')
  !  READ(*,*) number_global_z_elements
  !  WRITE(*,'("Enter the number of domains :")')
  !  READ(*,*) number_of_domains
  !ENDIF

  number_global_x_elements=1
  number_global_y_elements=1
  number_global_z_elements=1   
  number_of_domains=1

  !Broadcast the number of elements in the X,Y and Z directions and the number of partitions to the other computational nodes
  CALL MPI_BCAST(number_global_x_elements,1,MPI_INTEGER,0,MPI_COMM_WORLD,MPI_IERROR)
  CALL MPI_ERROR_CHECK("MPI_BCAST",MPI_IERROR,ERR,ERROR,*999)
  CALL MPI_BCAST(number_global_y_elements,1,MPI_INTEGER,0,MPI_COMM_WORLD,MPI_IERROR)
  CALL MPI_ERROR_CHECK("MPI_BCAST",MPI_IERROR,ERR,ERROR,*999)
  CALL MPI_BCAST(number_global_z_elements,1,MPI_INTEGER,0,MPI_COMM_WORLD,MPI_IERROR)
  CALL MPI_ERROR_CHECK("MPI_BCAST",MPI_IERROR,ERR,ERROR,*999)
  CALL MPI_BCAST(NUMBER_OF_DOMAINS,1,MPI_INTEGER,0,MPI_COMM_WORLD,MPI_IERROR)
  CALL MPI_ERROR_CHECK("MPI_BCAST",MPI_IERROR,ERR,ERROR,*999)

  !Create a CS - default is 3D rectangular cartesian CS with 0,0,0 as origin
  coordinate_system_user_number=1
  number_of_spatial_coordinates=3
  NULLIFY(COORDINATE_SYSTEM)
  CALL COORDINATE_SYSTEM_CREATE_START(coordinate_system_user_number,COORDINATE_SYSTEM,ERR,ERROR,*999)
  CALL COORDINATE_SYSTEM_TYPE_SET(COORDINATE_SYSTEM,COORDINATE_RECTANGULAR_CARTESIAN_TYPE,ERR,ERROR,*999)
  CALL COORDINATE_SYSTEM_DIMENSION_SET(COORDINATE_SYSTEM,number_of_spatial_coordinates,ERR,ERROR,*999)
  CALL COORDINATE_SYSTEM_ORIGIN_SET(COORDINATE_SYSTEM,(/0.0_DP,0.0_DP,0.0_DP/),ERR,ERROR,*999)
  CALL COORDINATE_SYSTEM_CREATE_FINISH(COORDINATE_SYSTEM,ERR,ERROR,*999)

  !Create a region and assign the CS to the region
  region_user_number=1
  NULLIFY(REGION)
  CALL REGION_CREATE_START(region_user_number,WORLD_REGION,REGION,ERR,ERROR,*999)
  CALL REGION_COORDINATE_SYSTEM_SET(REGION,COORDINATE_SYSTEM,ERR,ERROR,*999)
  CALL REGION_CREATE_FINISH(REGION,ERR,ERROR,*999)

  !Define basis function - tri-linear Lagrange  
  basis_user_number=1 
  number_of_xi_coordinates=3
  NULLIFY(BASIS)
  CALL BASIS_CREATE_START(basis_user_number,BASIS,ERR,ERROR,*999) 
  CALL BASIS_TYPE_SET(BASIS,BASIS_LAGRANGE_HERMITE_TP_TYPE,ERR,ERROR,*999)
  CALL BASIS_NUMBER_OF_XI_SET(BASIS,number_of_xi_coordinates,ERR,ERROR,*999)
  CALL BASIS_INTERPOLATION_XI_SET(BASIS,(/BASIS_LINEAR_LAGRANGE_INTERPOLATION, &
    & BASIS_LINEAR_LAGRANGE_INTERPOLATION,BASIS_LINEAR_LAGRANGE_INTERPOLATION/),ERR,ERROR,*999)
  CALL BASIS_QUADRATURE_NUMBER_OF_GAUSS_XI_SET(BASIS, &
    & (/BASIS_MID_QUADRATURE_SCHEME,BASIS_MID_QUADRATURE_SCHEME,BASIS_MID_QUADRATURE_SCHEME/),ERR,ERROR,*999)  
  CALL BASIS_CREATE_FINISH(BASIS,ERR,ERROR,*999)

  !Create a mesh
  mesh_user_number=1
  number_of_mesh_dimensions=3
  number_of_mesh_components=1
  total_number_of_elements=2
  NULLIFY(MESH)
  CALL MESH_CREATE_START(mesh_user_number,REGION,number_of_mesh_dimensions,MESH,ERR,ERROR,*999)    

  CALL MESH_NUMBER_OF_COMPONENTS_SET(MESH,number_of_mesh_components,ERR,ERROR,*999) 
  CALL MESH_NUMBER_OF_ELEMENTS_SET(MESH,total_number_of_elements,ERR,ERROR,*999)  

  !define nodes for the mesh
  total_number_of_nodes=12
  NULLIFY(NODES)
  CALL NODES_CREATE_START(REGION,total_number_of_nodes,NODES,ERR,ERROR,*999)
  CALL NODES_CREATE_FINISH(NODES,ERR,ERROR,*999)

  mesh_component_number=1
  NULLIFY(ELEMENTS)
  CALL MESH_TOPOLOGY_ELEMENTS_CREATE_START(MESH,mesh_component_number,BASIS,ELEMENTS,ERR,ERROR,*999)
  CALL MESH_TOPOLOGY_ELEMENTS_ELEMENT_NODES_SET(1,ELEMENTS,(/1,9,3,10,5,11,7,12/),ERR,ERROR,*999)
  CALL MESH_TOPOLOGY_ELEMENTS_ELEMENT_NODES_SET(2,ELEMENTS,(/9,2,10,4,11,6,12,8/),ERR,ERROR,*999)
  CALL MESH_TOPOLOGY_ELEMENTS_CREATE_FINISH(ELEMENTS,ERR,ERROR,*999)

  CALL MESH_CREATE_FINISH(MESH,ERR,ERROR,*999) 

  !Create a decomposition
  decomposition_user_number=1
  NULLIFY(DECOMPOSITION)
  CALL DECOMPOSITION_CREATE_START(decomposition_user_number,MESH,DECOMPOSITION,ERR,ERROR,*999)
  CALL DECOMPOSITION_TYPE_SET(DECOMPOSITION,DECOMPOSITION_CALCULATED_TYPE,ERR,ERROR,*999)
  CALL DECOMPOSITION_NUMBER_OF_DOMAINS_SET(DECOMPOSITION,number_of_domains,ERR,ERROR,*999)
  CALL DECOMPOSITION_CREATE_FINISH(DECOMPOSITION,ERR,ERROR,*999)

  !Create a field to put the geometry (defualt is geometry)
  field_geomtery_user_number=1  
  field_geometry_number_of_varaiables=1
  field_geometry_number_of_components=3
  NULLIFY(GEOMETRIC_FIELD)
  CALL FIELD_CREATE_START(field_geomtery_user_number,REGION,GEOMETRIC_FIELD,ERR,ERROR,*999)
  CALL FIELD_MESH_DECOMPOSITION_SET(GEOMETRIC_FIELD,DECOMPOSITION,ERR,ERROR,*999)
  CALL FIELD_TYPE_SET(GEOMETRIC_FIELD,FIELD_GEOMETRIC_TYPE,ERR,ERROR,*999)  
  CALL FIELD_NUMBER_OF_VARIABLES_SET(GEOMETRIC_FIELD,field_geometry_number_of_varaiables,ERR,ERROR,*999)
  CALL FIELD_NUMBER_OF_COMPONENTS_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,field_geometry_number_of_components,ERR,ERROR,*999)  
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,1,mesh_component_number,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,2,mesh_component_number,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,3,mesh_component_number,ERR,ERROR,*999)
  CALL FIELD_CREATE_FINISH(GEOMETRIC_FIELD,ERR,ERROR,*999)

  !node 1
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,1,1,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,1,2,0.0_DP,ERR,ERROR,*999)  
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,1,3,0.0_DP,ERR,ERROR,*999)
  !node 2
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,2,1,1.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,2,2,0.0_DP,ERR,ERROR,*999)  
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,2,3,0.0_DP,ERR,ERROR,*999)
  !node 3
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,3,1,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,3,2,1.0_DP,ERR,ERROR,*999)  
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,3,3,0.0_DP,ERR,ERROR,*999)
  !node 4
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,4,1,1.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,4,2,1.0_DP,ERR,ERROR,*999)  
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,4,3,0.0_DP,ERR,ERROR,*999)
  !node 5
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,5,1,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,5,2,0.0_DP,ERR,ERROR,*999)  
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,5,3,1.0_DP,ERR,ERROR,*999)
  !node 6
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,6,1,1.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,6,2,0.0_DP,ERR,ERROR,*999)  
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,6,3,1.0_DP,ERR,ERROR,*999)
  !node 7
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,7,1,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,7,2,1.0_DP,ERR,ERROR,*999)  
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,7,3,1.0_DP,ERR,ERROR,*999)
  !node 8
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,8,1,1.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,8,2,1.0_DP,ERR,ERROR,*999)  
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,8,3,1.0_DP,ERR,ERROR,*999)
  !node 9
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,9,1,0.5_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,9,2,0.0_DP,ERR,ERROR,*999)  
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,9,3,0.0_DP,ERR,ERROR,*999)
  !node 10
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,10,1,0.5_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,10,2,1.0_DP,ERR,ERROR,*999)  
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,10,3,0.0_DP,ERR,ERROR,*999)
  !node 11
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,11,1,0.5_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,11,2,0.0_DP,ERR,ERROR,*999)  
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,11,3,1.0_DP,ERR,ERROR,*999)
  !node 12
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,12,1,0.5_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,12,2,1.0_DP,ERR,ERROR,*999)  
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,12,3,1.0_DP,ERR,ERROR,*999)

  !Create a fibre field and attach it to the geometric field  
  field_fibre_user_number=2  
  field_fibre_number_of_varaiables=1
  field_fibre_number_of_components=3
  NULLIFY(FIBRE_FIELD)
  CALL FIELD_CREATE_START(field_fibre_user_number,REGION,FIBRE_FIELD,ERR,ERROR,*999)
  CALL FIELD_TYPE_SET(FIBRE_FIELD,FIELD_FIBRE_TYPE,ERR,ERROR,*999)
  CALL FIELD_MESH_DECOMPOSITION_SET(FIBRE_FIELD,DECOMPOSITION,ERR,ERROR,*999)        
  CALL FIELD_GEOMETRIC_FIELD_SET(FIBRE_FIELD,GEOMETRIC_FIELD,ERR,ERROR,*999)
  CALL FIELD_NUMBER_OF_VARIABLES_SET(FIBRE_FIELD,field_fibre_number_of_varaiables,ERR,ERROR,*999)
  CALL FIELD_NUMBER_OF_COMPONENTS_SET(FIBRE_FIELD,FIELD_U_VARIABLE_TYPE,field_fibre_number_of_components,ERR,ERROR,*999)  
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(FIBRE_FIELD,FIELD_U_VARIABLE_TYPE,1,mesh_component_number,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(FIBRE_FIELD,FIELD_U_VARIABLE_TYPE,2,mesh_component_number,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(FIBRE_FIELD,FIELD_U_VARIABLE_TYPE,3,mesh_component_number,ERR,ERROR,*999)
  CALL FIELD_CREATE_FINISH(FIBRE_FIELD,ERR,ERROR,*999)

  !Create a material field and attach it to the geometric field  
  field_material_user_number=3  
  field_material_number_of_varaiables=1
  field_material_number_of_components=2
  NULLIFY(MATERIAL_FIELD)
  CALL FIELD_CREATE_START(field_material_user_number,REGION,MATERIAL_FIELD,ERR,ERROR,*999)
  CALL FIELD_TYPE_SET(MATERIAL_FIELD,FIELD_MATERIAL_TYPE,ERR,ERROR,*999)
  CALL FIELD_MESH_DECOMPOSITION_SET(MATERIAL_FIELD,DECOMPOSITION,ERR,ERROR,*999)        
  CALL FIELD_GEOMETRIC_FIELD_SET(MATERIAL_FIELD,GEOMETRIC_FIELD,ERR,ERROR,*999)
  CALL FIELD_NUMBER_OF_VARIABLES_SET(MATERIAL_FIELD,field_material_number_of_varaiables,ERR,ERROR,*999)
  CALL FIELD_NUMBER_OF_COMPONENTS_SET(MATERIAL_FIELD,FIELD_U_VARIABLE_TYPE,field_material_number_of_components,ERR,ERROR,*999)  
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(MATERIAL_FIELD,FIELD_U_VARIABLE_TYPE,1,mesh_component_number,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(MATERIAL_FIELD,FIELD_U_VARIABLE_TYPE,2,mesh_component_number,ERR,ERROR,*999)
  CALL FIELD_CREATE_FINISH(MATERIAL_FIELD,ERR,ERROR,*999)

  !Set Mooney-Rivlin constants c10 and c01 to 2.0 and 3.0 respectively.
  CALL FIELD_COMPONENT_VALUES_INITIALISE(MATERIAL_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,2.0_DP,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_VALUES_INITIALISE(MATERIAL_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,2,3.0_DP,ERR,ERROR,*999)

  !Create a dependent field with two variables and four components
  field_dependent_user_number=4  
  field_dependent_number_of_varaiables=2
  field_dependent_number_of_components=4
  NULLIFY(DEPENDENT_FIELD)
  CALL FIELD_CREATE_START(field_dependent_user_number,REGION,DEPENDENT_FIELD,ERR,ERROR,*999)
  CALL FIELD_TYPE_SET(DEPENDENT_FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)  
  CALL FIELD_MESH_DECOMPOSITION_SET(DEPENDENT_FIELD,DECOMPOSITION,ERR,ERROR,*999)
  CALL FIELD_GEOMETRIC_FIELD_SET(DEPENDENT_FIELD,GEOMETRIC_FIELD,ERR,ERROR,*999) 
  CALL FIELD_DEPENDENT_TYPE_SET(DEPENDENT_FIELD,FIELD_DEPENDENT_TYPE,ERR,ERROR,*999) 
  CALL FIELD_NUMBER_OF_VARIABLES_SET(DEPENDENT_FIELD,field_dependent_number_of_varaiables,ERR,ERROR,*999)
  CALL FIELD_NUMBER_OF_COMPONENTS_SET(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,field_dependent_number_of_components, &
    & ERR,ERROR,*999)
  CALL FIELD_NUMBER_OF_COMPONENTS_SET(DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE,field_dependent_number_of_components, &
    & ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,1,mesh_component_number,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,2,mesh_component_number,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,3,mesh_component_number,ERR,ERROR,*999)  
  CALL FIELD_COMPONENT_INTERPOLATION_SET(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,4,FIELD_ELEMENT_BASED_INTERPOLATION,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE,1,mesh_component_number,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE,2,mesh_component_number,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE,3,mesh_component_number,ERR,ERROR,*999)  
  CALL FIELD_COMPONENT_INTERPOLATION_SET(DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE,4,FIELD_ELEMENT_BASED_INTERPOLATION, &
    & ERR,ERROR,*999)
  CALL FIELD_CREATE_FINISH(DEPENDENT_FIELD,ERR,ERROR,*999)  

  !Create the equations_set
  equation_set_user_number=1
  CALL EQUATIONS_SET_CREATE_START(equation_set_user_number,REGION,FIBRE_FIELD,EQUATIONS_SET,ERR,ERROR,*999)
  CALL EQUATIONS_SET_SPECIFICATION_SET(EQUATIONS_SET,EQUATIONS_SET_ELASTICITY_CLASS, &
    & EQUATIONS_SET_FINITE_ELASTICITY_TYPE,EQUATIONS_SET_NO_SUBTYPE,ERR,ERROR,*999)
  CALL EQUATIONS_SET_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)

  CALL EQUATIONS_SET_DEPENDENT_CREATE_START(equations_set,field_dependent_user_number,DEPENDENT_FIELD,ERR,ERROR,*999) 
  CALL EQUATIONS_SET_DEPENDENT_CREATE_FINISH(equations_set,ERR,ERROR,*999)

  CALL EQUATIONS_SET_MATERIALS_CREATE_START(EQUATIONS_SET,field_material_user_number,MATERIAL_FIELD,ERR,ERROR,*999)  
  CALL EQUATIONS_SET_MATERIALS_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)

  !Create the equations set equations
  NULLIFY(EQUATIONS)
  CALL EQUATIONS_SET_EQUATIONS_CREATE_START(EQUATIONS_SET,EQUATIONS,ERR,ERROR,*999)
  CALL EQUATIONS_SPARSITY_TYPE_SET(EQUATIONS,EQUATIONS_SPARSE_MATRICES,ERR,ERROR,*999)
  CALL EQUATIONS_OUTPUT_TYPE_SET(EQUATIONS,EQUATIONS_NO_OUTPUT,ERR,ERROR,*999)
  CALL EQUATIONS_SET_EQUATIONS_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)   

  !Initialise dependent field from undeformed geometry and displacement bcs and set hydrostatic pressure
  CALL FIELD_PARAMETERS_TO_FIELD_PARAMETERS_COMPONENT_COPY(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
    & 1,DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,ERR,ERROR,*999)
  CALL FIELD_PARAMETERS_TO_FIELD_PARAMETERS_COMPONENT_COPY(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
    & 2,DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,2,ERR,ERROR,*999)
  CALL FIELD_PARAMETERS_TO_FIELD_PARAMETERS_COMPONENT_COPY(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
    & 3,DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,3,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_VALUES_INITIALISE(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,4,-5.0_DP,ERR,ERROR,*999)

  !Prescribe boundary conditions (absolute nodal parameters)
  NULLIFY(BOUNDARY_CONDITIONS)
  CALL EQUATIONS_SET_BOUNDARY_CONDITIONS_CREATE_START(EQUATIONS_SET,BOUNDARY_CONDITIONS,ERR,ERROR,*999)

  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,1,1,BOUNDARY_CONDITION_FIXED,0.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,2,1,BOUNDARY_CONDITION_FIXED,1.1_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,3,1,BOUNDARY_CONDITION_FIXED,0.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,4,1,BOUNDARY_CONDITION_FIXED,1.1_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,5,1,BOUNDARY_CONDITION_FIXED,0.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,6,1,BOUNDARY_CONDITION_FIXED,1.1_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,7,1,BOUNDARY_CONDITION_FIXED,0.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,8,1,BOUNDARY_CONDITION_FIXED,1.2_DP,ERR,ERROR,*999)

  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,1,2,BOUNDARY_CONDITION_FIXED,0.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,2,2,BOUNDARY_CONDITION_FIXED,0.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,3,2,BOUNDARY_CONDITION_FIXED,1.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,4,2,BOUNDARY_CONDITION_FIXED,1.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,5,2,BOUNDARY_CONDITION_FIXED,0.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,6,2,BOUNDARY_CONDITION_FIXED,0.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,7,2,BOUNDARY_CONDITION_FIXED,1.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,8,2,BOUNDARY_CONDITION_FIXED,1.0_DP,ERR,ERROR,*999)

  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,1,3,BOUNDARY_CONDITION_FIXED,0.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,3,3,BOUNDARY_CONDITION_FIXED,0.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,5,3,BOUNDARY_CONDITION_FIXED,1.0_DP,ERR,ERROR,*999)
  CALL BOUNDARY_CONDITIONS_SET_NODE(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,7,3,BOUNDARY_CONDITION_FIXED,1.0_DP,ERR,ERROR,*999)

  CALL EQUATIONS_SET_BOUNDARY_CONDITIONS_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)

  !Define the problem
  NULLIFY(PROBLEM)
  problem_user_number=1
  CALL PROBLEM_CREATE_START(problem_user_number,PROBLEM,ERR,ERROR,*999)
  CALL PROBLEM_SPECIFICATION_SET(PROBLEM,PROBLEM_ELASTICITY_CLASS,PROBLEM_FINITE_ELASTICITY_TYPE, &
    & PROBLEM_NO_SUBTYPE,ERR,ERROR,*999)
  CALL PROBLEM_CREATE_FINISH(PROBLEM,ERR,ERROR,*999)

  !Create the problem control loop
  CALL PROBLEM_CONTROL_LOOP_CREATE_START(PROBLEM,ERR,ERROR,*999)
  CALL PROBLEM_CONTROL_LOOP_CREATE_FINISH(PROBLEM,ERR,ERROR,*999)

  !Create the problem solvers
  NULLIFY(SOLVER)
  NULLIFY(LINEAR_SOLVER)
  CALL PROBLEM_SOLVERS_CREATE_START(PROBLEM,ERR,ERROR,*999)
  CALL PROBLEM_SOLVER_GET(PROBLEM,CONTROL_LOOP_NODE,1,SOLVER,ERR,ERROR,*999)
  CALL SOLVER_OUTPUT_TYPE_SET(SOLVER,SOLVER_PROGRESS_OUTPUT,ERR,ERROR,*999)
  CALL SOLVER_NEWTON_JACOBIAN_CALCULATION_TYPE_SET(SOLVER,SOLVER_NEWTON_JACOBIAN_FD_CALCULATED,ERR,ERROR,*999)
  !CALL SOLVER_NEWTON_LINESEARCH_ALPHA_SET(SOLVER,0.1_DP,ERR,ERROR,*999)   
  !CALL SOLVER_OUTPUT_TYPE_SET(SOLVER,SOLVER_MATRIX_OUTPUT,ERR,ERROR,*999)      
  CALL PROBLEM_SOLVERS_CREATE_FINISH(PROBLEM,ERR,ERROR,*999)

  !Create the problem solver equations
  NULLIFY(SOLVER)
  NULLIFY(SOLVER_EQUATIONS)
  CALL PROBLEM_SOLVER_EQUATIONS_CREATE_START(PROBLEM,ERR,ERROR,*999)   
  CALL PROBLEM_SOLVER_GET(PROBLEM,CONTROL_LOOP_NODE,1,SOLVER,ERR,ERROR,*999)
  CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
  CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
  CALL SOLVER_EQUATIONS_EQUATIONS_SET_ADD(SOLVER_EQUATIONS,EQUATIONS_SET,EQUATIONS_SET_INDEX,ERR,ERROR,*999)
  CALL PROBLEM_SOLVER_EQUATIONS_CREATE_FINISH(PROBLEM,ERR,ERROR,*999)

  !Solve problem
  CALL PROBLEM_SOLVE(PROBLEM,ERR,ERROR,*999)

  !Output solution  
  number_of_global_dependent_dofs=DEPENDENT_FIELD%VARIABLES(1)%NUMBER_OF_GLOBAL_DOFS
  CALL WRITE_STRING(GENERAL_OUTPUT_TYPE," deformed geometry & hydrostatic pressure",ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_DATA_GET(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,FIELD_DATA,ERR,ERROR,*999) 
  CALL WRITE_STRING_VECTOR(GENERAL_OUTPUT_TYPE,1,1,number_of_global_dependent_dofs,1,1,FIELD_DATA,'(2x,f10.6)','(2x,f10.6)', &
    & ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_DATA_RESTORE(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,FIELD_DATA,ERR,ERROR,*999)
  CALL WRITE_STRING(GENERAL_OUTPUT_TYPE," nodal reaction forces",ERR,ERROR,*999)
  !CALL FIELD_PARAMETER_SET_DATA_GET(DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,FIELD_DATA,ERR,ERROR,*999)  
  !CALL WRITE_STRING_VECTOR(GENERAL_OUTPUT_TYPE,1,1,number_of_global_dependent_dofs,1,1,FIELD_DATA,'(2x,f10.6)','(2x,f10.6)', &
  !  & ERR,ERROR,*999)
  !CALL FIELD_PARAMETER_SET_DATA_RESTORE(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,FIELD_DATA,ERR,ERROR,*999)

  DO dof_idx=1,number_of_global_dependent_dofs
    WRITE(6,'(2x,f10.6)') PROBLEM%CONTROL_LOOP%SOLVERS%SOLVERS(1)%PTR%SOLVER_EQUATIONS%SOLVER_MAPPING% &
      & EQUATIONS_SETS(1)%PTR%EQUATIONS%EQUATIONS_MATRICES%NONLINEAR_MATRICES%RESIDUAL%CMISS%DATA_DP(dof_idx)
  ENDDO

  !Calculate and output the elapsed user and system times
  CALL CPU_TIMER(USER_CPU,STOP_USER_TIME,ERR,ERROR,*999)
  CALL CPU_TIMER(SYSTEM_CPU,STOP_SYSTEM_TIME,ERR,ERROR,*999)
  CALL WRITE_STRING_FMT_TWO_VALUE(GENERAL_OUTPUT_TYPE," USER TIME = ",STOP_USER_TIME(1)-START_USER_TIME(1),'(f10.6)', &
    & "  : SYSTEM TIME = ",STOP_SYSTEM_TIME(1)-START_SYSTEM_TIME(1),'(f10.6)',ERR,ERROR,*999)

  CALL CMISS_FINALISE(ERR,ERROR,*999)

  CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"*** PROGRAM SUCCESSFULLY COMPLETED ******",ERR,ERROR,*999)

  STOP
999 CALL CMISS_WRITE_ERROR(ERR,ERROR)
  STOP


END PROGRAM TWOELEMENTTRILINEAR

