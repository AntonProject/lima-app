https://dev.lima.uz/swagger/index.html?urls.primaryName=Storage.API%20-%201.0

Servers
#### /api

## Files

#### Parameters Tryitout NoparametersRequestbodymultipart/form-data

### Lengthinteger($int64)

### Namestring

#### Responses

#### L i n k s

#### Parameters Tryitout

### uid ***

string

_(pat_
_h)_

#### Responses

#### _N__o__li__n__k__s_

#### Parameters TryitoutNameDescription

#### L i n k s _N__o__li__n__k__s__(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters Tryitout

### uid *

string

_(pat_
_h)_

#### Responses

#### L i n k s _N__o__li__n__k__s__N__o__li__n__k__s_

Servers
#### /api

## Feedback

####
POST
### /Feedback

#### Parameters Tryitout NoparametersRequestbodymultipart/form-data Responses

#### L i n k s

#### _o__li__n__k__s_http

#### s : / / dev .lima . u z / swagger / index . html ? urls . pri

#### maryName = KBase . API % 2 0 - % 2 0 1 . 0

Servers
#### /api Authorize

## Documents

#### Parameters Tryitout NoparametersRequestbodymultipart/form-data

#### Название документа

### Lengthinteger($int64)

### Namestring

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(que_
_ry)_

_(que_
_ry)_

_(que_
_ry)_

_(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
### SchemasServers
#### /api/dict

## Categories

#### Authorize

####
GET
### /Categories

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Categories /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
## Common

####
GET
### /Common /countries

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

### count ryid *

integer($int32)

_(path)_

#### Responses

#### L i n k s

### /Common /areas

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters

#### TryitoutName Description

### regio nId *

integer($int32)

_(path)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### _o__li__n__k__s_
## Directions

####
GET
### /Directions

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Directions

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Directions /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Directions /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
## Doctors

####
GET
### /Doctors

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

### doctor_p osition_idinteger($
int32)

_(query)_

### organizat ion_idarray[integer]

_(query)_

_(query)_

### classifica tion_idinteger($
int32)

_(query)_

### health_care_facility_type_idinteger($
int32)

_(query)_

### company _idinteger($
int32)

_(query)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

### doctor_p osition_idinteger($
int32)

_(query)_

### organizat ion_idarray[integer]

_(query)_

_(query)_

### classifica tion_idinteger($
int32)

_(query)_

### health_care_facility_type_idinteger($
int32)

_(query)_

### company _idinteger($
int32)

_(query)_

#### Responses

#### L i n k s

### /Doctors /{phone}

#### Parameters TryitoutName Description

### pho ne *

string

_(path_
_)_

#### Responses

#### L i n k s

### /Doctors /id /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### docto rId *

integer($int32)

_(path)_

#### Responses

#### L i n k s

### /Doctors /add

#### Parameters Tryitout No parameters

"id": 0,
"organization_id": [
0
],
"full_name": "string",
"comment": "string",
"phone": "string",
"position_id": 0,
"category_id": 0,
"birthday": "2026-04-14T11:55:51.838Z",
"hobby": "string",
"interests": "string"
}

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### doctorI d *

integer(
$int32)

_(path)_

### organiz ationId *

integer(
$int32)

_(path)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### doctor Id *

integer
($int32
)

_(path)_

### comp anyId *

integer
($int32
)

_(path)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### org_ idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters

}

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### docto rId *

integer($int32)

_(path)_

#### Responses

#### L i n k s

### /Doctors /favorites

#### Parameters TryitoutName Description

### user _idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s

### /Doctors /favorites /all

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

### doctor_p osition_idinteger($
int32)

_(query)_

### organizat ion_idarray[integer]

_(query)_

_(query)_

### classifica tion_idinteger($
int32)

_(query)_

### health_care_facility_type_idinteger($
int32)

_(query)_

### company _idinteger($
int32)

_(query)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Doctors /count

#### Parameters

#### TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

### doctor_p osition_idinteger($
int32)

_(query)_

### organizat ion_idarray[integer]

_(query)_

_(query)_

### classifica tion_idinteger($
int32)

_(query)_

### health_care_facility_type_idinteger($
int32)

_(query)_

### company _idinteger($
int32)

_(query)_

#### Responses

#### L i n k s

### /Doctors /visited

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Doctors /visited

#### Parameters TryitoutName Description

### pag e

integer(
$int
32)

_(que_
_ry)_

### start_datestring($
date-time)

_(que_
_ry)_

### end_datestring($
date-time)

_(que_
_ry)_

### doctor_idinteger(
$int
32)

_(que_
_ry)_

### region_idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s

### /Doctors /sync

#### Parameters

#### TryitoutName Description

### sync _idinteger(
$int
64)

_(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### sync _idinteger(
$int
64)

_(que_
_ry)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
## Drugs

####
GET
### /Drugs

#### Parameters Tryitout No parameters Responses

#### i n k s

### /Drugs

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Drugs /company

#### Parameters TryitoutName Description

_(que_
_ry)_

### nam e

string

_(que_
_ry)_

### company_idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s

### /Drugs /bindings

#### Parameters TryitoutName Description

_(que_
_ry)_

### company_idinteger(
$int
32)

_(que_
_ry)_

### nam e

string

_(que_
_ry)_

_(que_
_ry)_

_(que_
_ry)_

#### Responses

#### L i n k s

### /Drugs /bindings

#### Parameters Tryitout NoparametersRequestbodymultipart/form-data

### drug_i d *

integer
($int32
)

### produc er_id *

integer
($int32
)

### directio n_idinteger
($int32
)

### Namestring

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Requestbodymultipart/form-data

### drug_i d *

integer
($int32
)

### produc er_id *

integer
($int32
)

### directio n_idinteger
($int32
)

### Namestring

#### Responses

#### L i n k s

#### Parameters Tryitout

### uid *

string

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### phot oId *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters

#### Responses

#### L i n k s

### /Drugs /update

#### Parameters Tryitout No parameters

#### Responses

#### L i n k s

### /Drugs /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Request body

#### Responses

#### L i n k s

### /Drugs /sync

#### Parameters TryitoutName Description

### sync _idinteger(
$int
64)

_(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### sync _idinteger(
$int
64)

_(que_
_ry)_

#### Responses

#### L i n k s

### /Drugs /company /sync

#### Parameters TryitoutName Description

### sync _idinteger(
$int
64)

_(que_
_ry)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
## Lines

####
GET
### /Lines

#### Parameters Tryitout No parameters Responses

#### i n k s

### /Lines

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Lines /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Lines /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Lines /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
## Organizations

####
GET
### /Organizations /{id}

#### Parameters

#### TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### inn *

integer(
$int
64)

_(pat_
_h)_

#### Responses

#### L i n k s

### /Organizations /add

#### Parameters Tryitout No parameters

"phone3": "string",
"inn": 0,
"type_id": 3,
"health_care_facility_type_id": 0,
"classification_id": 0,
"region_id": 0,
"area_id": 0,
"latitude": 0,
"longitude": 0,
"doctors_ids": [
0
],
"responsible_person": "string",
"category_id": 0,
"pinfl": 99999999999999
}

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### sour ce *

string

_(path_
_)_

#### Responses

#### L i n k s

### /Organizations

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

### doctor_p osition_idinteger($
int32)

_(query)_

_(query)_

_(query)_

#### --truefalse

### classifica tion_idinteger($
int32)

_(query)_

### health_care_facility_type_idinteger($
int32)

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

#### --truefalse

#### Responses

#### L i n k s

### /Organizations

#### Parameters Tryitout No parameters

"phone": "string",
"phone2": "string",
"latitude": 0,
"longitude": 0,
"no_limit": true
}

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

### doctor_p osition_idinteger($
int32)

_(query)_

_(query)_

_(query)_

### classifica tion_idinteger($
int32)

_(query)_

### health_care_facility_type_idinteger($
int32)

_(query)_

_(query)_

_(query)_

_(query)_

#### --truefalse

_(query)_

_(query)_

#### --truefalse

#### Responses

#### L i n k s

### /Organizations /find

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

### doctor_p osition_idinteger($
int32)

_(query)_

_(query)_

_(query)_

### classifica tion_idinteger($
int32)

_(query)_

### health_care_facility_type_idinteger($
int32)

_(query)_

_(query)_

_(query)_

_(query)_

#### --truefalse

_(query)_

_(query)_

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### latitu de *

number($float)

_(query_
_)_

### longit ude *

number($float)

_(query_
_)_

_(query_
_)_

### type_i d

array[
integer]

_(query_
_)_

_(query_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### organiza tionId *

integer($
int32)

_(path)_

_(query)_

_(query)_

_(query)_

_(query)_

### doctor_p osition_idinteger($
int32)

_(query)_

### organizat ion_idarray[integer]

_(query)_

_(query)_

### classifica tion_idinteger($
int32)

_(query)_

### health_care_facility_type_idinteger($
int32)

_(query)_

### company _idinteger($
int32)

_(query)_

#### Responses

#### L i n k s

### /Organizations /count

#### Parameters TryitoutName Description

### type _idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Organizations /types

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

### doctor_p osition_idinteger($
int32)

_(query)_

_(query)_

_(query)_

#### --truefalse

### classifica tion_idinteger($
int32)

_(query)_

### health_care_facility_type_idinteger($
int32)

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### organiz ationId *

integer(
$int32)

_(path)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### {name}

#### Parameters TryitoutName Description

### organzi ationId *

integer(
$int32)

_(path)_

_(path)_

#### Responses

#### L i n k s

#### Parameters

#### TryitoutName Description

### organiz ationId *

integer(
$int32)

_(path)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### organiz ationId *

integer(
$int32)

_(path)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Organizations /sync

#### Parameters TryitoutName Description

### sync _idinteger(
$int
64)

_(que_
_ry)_

### region_idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
## Producers

####
GET

### /Producers

#### Parameters TryitoutName Description

_(que_
_ry)_

### nam e

string

_(que_
_ry)_

#### Responses

#### L i n k s

### /Producers

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Producers /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Producers /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Request body

#### Responses

#### L i n k s

#### _o__li__n__k__s_
### Schemas

### ProducerRequest{

### Selectadefinition

#### Visits.API - 1.0Company.API - 1.0Payments.API - 1.0Users.API - 1.0Warehouse.API - 1.0Configuration.API - 1.0Cart.API - 1.0Reporting.API - 1.0Storage.API - 1.0Feedback.API - 1.0KBase.API - 1.0Dictionaries.API - 1.0Logistics.API - 1.0Attendance.API - 1.0

Servers
#### /api

## Courier

#### Parameters Tryitout No parameters Responses

#### L i n k s _N__o__li__n__k_

{
"id": 0,
"status": 1,
"status_name": "string",
"type": 1,
"type_name": "string",
"logist_id": 0,
"date_created": "2026-04-14T11:56:34.651Z",
"delivery_date": "2026-04-14T11:56:34.651Z",
"route": [
{
"id": 0,
"status": 0,
"visit_id": 0,
"name": "string",
"address": "string",
"type": "string",
"latitude": 0,
"longitude": 0,
"distance": 0
}
],
"driver": {
"id": 0,
"name": "string"
},
"car": {
"id": 0,
"name": "string",
"number": "string"
},
"dpd_delivery": {
"id": 0,
"sender_name": "string",
"sender_address": "string",
"sender_contact_fio": "string",
"sender_contact_phone": "string",
"pickup_time_period": "string",
"terminal_code": "string",
"pickup_city_id": 0,
"date_pickup": "2026-04-14T11:56:34.651Z",
"details": [
{

"id" 0

#### _s_

"id": 0,
"visit_id": 0,
"service_variant": "string",
"cargo_num_pack": 0,
"cargo_weight": 0,
"terminal_code": "string",
"receiver_name": "string",
"receiver_street": "string",
"receiver_contact_fio": "string",
"receiver_contact_phone": "string",
"delivery_city_id": 0,
"is_deleted": true
}
]
},
"shipments": [
{
"id": 0,
"visit_id": 0,
"status": 0,
"status_name": "string",
"organization": {
"id": 0,
"name": "string"
},
"source": {
"id": 0,
"region_id": 0,
"region_name": "string",
"area_id": 0,
"area_name": "string",
"address": "string",
"home": "string",
"latitude": 0,
"longitude": 0
},
"destination": {
"id": 0,
"region_id": 0,
"region_name": "string",
"area_id": 0,
"area_name": "string",
"address": "string",
"home": "string",
"latitude": 0,

,
"longitude": 0
},
"number_of_boxes": 0,
"number_of_drugs": 0,
"weight": 0,
"price_per_box": 0,
"price_per_km": 0,
"distance": 0,
"delivery_time": 0,
"date_of_creation":
"2026-04-14T11:56:34.651Z",
"delivery_scheduled": true,
"ready": true,
"comment": "string"
}
]
}
]

#### Parameters Tryitout No parameters Responses

{
"id": 0,
"status": 1,
"status_name": "string",
"type": 1,
"type_name": "string",
"logist_id": 0,
"date_created": "2026-04-14T11:56:34.654Z",
"delivery_date": "2026-04-14T11:56:34.654Z",
"route": [
{
"id": 0,
"status": 0,
"visit_id": 0,
"name": "string",
"address": "string",
"type": "string",
"latitude": 0,
"longitude": 0,
"distance": 0
}
],
"driver": {
"id": 0,
"name": "string"
},
"car": {
"id": 0,
"name": "string",
"number": "string"
},

"dpd delivery": {

#### L i n k s _N__o__li__n__k__s_dpd_delivery : {
"id": 0,
"sender_name": "string",
"sender_address": "string",
"sender_contact_fio": "string",
"sender_contact_phone": "string",
"pickup_time_period": "string",
"terminal_code": "string",
"pickup_city_id": 0,
"date_pickup": "2026-04-14T11:56:34.654Z",
"details": [
{
"id": 0,
"visit_id": 0,
"service_variant": "string",
"cargo_num_pack": 0,
"cargo_weight": 0,
"terminal_code": "string",
"receiver_name": "string",
"receiver_street": "string",
"receiver_contact_fio": "string",
"receiver_contact_phone": "string",
"delivery_city_id": 0,
"is_deleted": true
}
]
},
"shipments": [
{
"id": 0,
"visit_id": 0,
"status": 0,
"status_name": "string",
"organization": {
"id": 0,
"name": "string"
},
"source": {
"id": 0,
"region_id": 0,
"region_name": "string",
"area_id": 0,
"area_name": "string",
"address": "string",
"home": "string",

"lid " 0

"latitude": 0,
"longitude": 0
},
"destination": {
"id": 0,
"region_id": 0,
"region_name": "string",
"area_id": 0,
"area_name": "string",
"address": "string",
"home": "string",
"latitude": 0,
"longitude": 0
},
"number_of_boxes": 0,
"number_of_drugs": 0,
"weight": 0,
"price_per_box": 0,
"price_per_km": 0,
"distance": 0,
"delivery_time": 0,
"date_of_creation":
"2026-04-14T11:56:34.654Z",
"delivery_scheduled": true,
"ready": true,
"comment": "string"
}
]
}
]

#### Parameters TryitoutName Description

### delive ryId *

integer($int32)

_(path)_

#### Responses

#### L i n k s _N__o__li_

"id": 0,
"status": 1,
"status_name": "string",
"type": 1,
"type_name": "string",
"logist_id": 0,
"date_created": "2026-04-14T11:56:34.657Z",
"delivery_date": "2026-04-14T11:56:34.657Z",
"route": [
{
"id": 0,
"status": 0,
"visit_id": 0,
"name": "string",
"address": "string",
"type": "string",
"latitude": 0,
"longitude": 0,
"distance": 0
}
],
"driver": {
"id": 0,
"name": "string"
},
"car": {
"id": 0,
"name": "string",
"number": "string"
},
"dpd_delivery": {
"id": 0,
"sender_name": "string",
"sender_address": "string",
"sender_contact_fio": "string",
"sender_contact_phone": "string",
"pickup_time_period": "string",
"terminal_code": "string",
"pickup_city_id": 0,
"date_pickup": "2026-04-14T11:56:34.657Z",

"dtil " [

#### _li__n__k__s_

"details": [
{
"id": 0,
"visit_id": 0,
"service_variant": "string",
"cargo_num_pack": 0,
"cargo_weight": 0,
"terminal_code": "string",
"receiver_name": "string",
"receiver_street": "string",
"receiver_contact_fio": "string",
"receiver_contact_phone": "string",
"delivery_city_id": 0,
"is_deleted": true
}
]
},
"shipments": [
{
"id": 0,
"visit_id": 0,
"status": 0,
"status_name": "string",
"organization": {
"id": 0,
"name": "string"
},
"source": {
"id": 0,
"region_id": 0,
"region_name": "string",
"area_id": 0,
"area_name": "string",
"address": "string",
"home": "string",
"latitude": 0,
"longitude": 0
},
"destination": {
"id": 0,
"region_id": 0,
"region_name": "string",
"area_id": 0,
"area_name": "string",
"address": "string",

g,
"home": "string",
"latitude": 0,
"longitude": 0
},
"number_of_boxes": 0,
"number_of_drugs": 0,
"weight": 0,
"price_per_box": 0,
"price_per_km": 0,
"distance": 0,
"delivery_time": 0,
"date_of_creation": "2026-04-14T11:56:34.657Z",
"delivery_scheduled": true,
"ready": true,
"comment": "string"
}
]
}

#### _N__o__li__n__k__s_

#### Parameters TryitoutName Description

### shipm entId *

integer
($int32
)

_(path)_

#### Responses

#### L i n k s

#### _N__o__li__n__k__s__N__o__li__n__k__s__N__o__li__n__k__s_

#### Parameters TryitoutName Description

### shipm entId *

integer
($int32
)

_(path)_

#### Responses

#### L i n k s _N__o__li__n__k__s__N__o__li__n__k__s_

#### _N__o__li__n__k__s__N__o__li__n__k__s_

####
POST
### /Delivery

#### Parameters Tryitout

#### No parameters Responses

#### L i n k s

{
"id": 0,
"status": 1,
"status_name": "string",
"type": 1,
"type_name": "string",
"logist_id": 0,
"date_created": "2026-04-14T11:56:34.664Z",
"delivery_date": "2026-04-14T11:56:34.664Z",
"route": [
{
"id": 0,
"status": 0,
"visit_id": 0,
"name": "string",
"address": "string",
"type": "string",
"latitude": 0,
"longitude": 0,
"distance": 0
}
],
"driver": {
"id": 0,
"name": "string"
},
"car": {
"id": 0,
"name": "string",
"number": "string"
},
"dpd_delivery": {
"id": 0,
"sender_name": "string",
"sender_address": "string",
"sender_contact_fio": "string",
"sender_contact_phone": "string",
"pickup_time_period": "string",
"terminal_code": "string",
"pickup_city_id": 0,

#### _o__li__n__k__s_ppy,
"date_pickup": "2026-04-14T11:56:34.664Z",
"details": [
{
"id": 0,
"visit_id": 0,
"service_variant": "string",
"cargo_num_pack": 0,
"cargo_weight": 0,
"terminal_code": "string",
"receiver_name": "string",
"receiver_street": "string",
"receiver_contact_fio": "string",
"receiver_contact_phone": "string",
"delivery_city_id": 0,
"is_deleted": true
}
]
},
"shipments": [
{
"id": 0,
"visit_id": 0,
"status": 0,
"status_name": "string",
"organization": {
"id": 0,
"name": "string"
},
"source": {
"id": 0,
"region_id": 0,
"region_name": "string",
"area_id": 0,
"area_name": "string",
"address": "string",
"home": "string",
"latitude": 0,
"longitude": 0
},
"destination": {
"id": 0,
"region_id": 0,
"region_name": "string",
"area_id": 0,

"area name": "string"

area_name : string,
"address": "string",
"home": "string",
"latitude": 0,
"longitude": 0
},
"number_of_boxes": 0,
"number_of_drugs": 0,
"weight": 0,
"price_per_box": 0,
"price_per_km": 0,
"distance": 0,
"delivery_time": 0,
"date_of_creation": "2026-04-14T11:56:34.664Z",
"delivery_scheduled": true,
"ready": true,
"comment": "string"
}
]
}

#### _N__o__li__n__k__s_

#### _N__o__li__n__k__s__N__o__li__n__k__s_

### /Delivery

#### Parameters

#### TryitoutName Description

### type _idinteger(
$int
32)

_(que_
_ry)_

#### Responses

[
{
"id": 0,
"status": 1,
"status_name": "string",
"type": 1,
"type_name": "string",
"logist_id": 0,
"date_created": "2026-04-14T11:56:34.669Z",
"delivery_date": "2026-04-14T11:56:34.669Z",
"route": [
{
"id": 0,
"status": 0,
"visit_id": 0,
"name": "string",

#### L i n k s _N__o__li__n__k__s_

"address": "string",
"type": "string",
"latitude": 0,
"longitude": 0,
"distance": 0
}
],
"driver": {
"id": 0,
"name": "string"
},
"car": {
"id": 0,
"name": "string",
"number": "string"
},
"dpd_delivery": {
"id": 0,
"sender_name": "string",
"sender_address": "string",
"sender_contact_fio": "string",
"sender_contact_phone": "string",
"pickup_time_period": "string",
"terminal_code": "string",
"pickup_city_id": 0,
"date_pickup": "2026-04-14T11:56:34.669Z",
"details": [
{
"id": 0,
"visit_id": 0,
"service_variant": "string",
"cargo_num_pack": 0,
"cargo_weight": 0,
"terminal_code": "string",
"receiver_name": "string",
"receiver_street": "string",
"receiver_contact_fio": "string",
"receiver_contact_phone": "string",
"delivery_city_id": 0,
"is_deleted": true
}
]
},
"shipments": [

{

{
"id": 0,
"visit_id": 0,
"status": 0,
"status_name": "string",
"organization": {
"id": 0,
"name": "string"
},
"source": {
"id": 0,
"region_id": 0,
"region_name": "string",
"area_id": 0,
"area_name": "string",
"address": "string",
"home": "string",
"latitude": 0,
"longitude": 0
},
"destination": {
"id": 0,
"region_id": 0,
"region_name": "string",
"area_id": 0,
"area_name": "string",
"address": "string",
"home": "string",
"latitude": 0,
"longitude": 0
},
"number_of_boxes": 0,
"number_of_drugs": 0,
"weight": 0,
"price_per_box": 0,
"price_per_km": 0,
"distance": 0,
"delivery_time": 0,
"date_of_creation":
"2026-04-14T11:56:34.669Z",
"delivery_scheduled": true,
"ready": true,
"comment": "string"
}
]

}

}
]

#### _N__o__li__n__k__s_

### /Delivery /history

#### Parameters TryitoutName Description

### type _idinteger(
$int
32)

_(que_
_ry)_

#### Responses

[
{
"id": 0,
"status": 1,
"status_name": "string",
"type": 1,
"type_name": "string",
"logist_id": 0,
"date_created": "2026-04-14T11:56:34.672Z",
"delivery_date": "2026-04-14T11:56:34.672Z",
"route": [
{
"id": 0,
"status": 0,
"visit_id": 0,
"name": "string",
"address": "string",
"type": "string",
"latitude": 0,
"longitude": 0,
"distance": 0
}
],
"driver": {
"id": 0,
"name": "string"
},
"car": {
"id": 0,
"name": "string",

#### L i n k s _N__o__li__n__k__s_

"number": "string"
},
"dpd_delivery": {
"id": 0,
"sender_name": "string",
"sender_address": "string",
"sender_contact_fio": "string",
"sender_contact_phone": "string",
"pickup_time_period": "string",
"terminal_code": "string",
"pickup_city_id": 0,
"date_pickup": "2026-04-14T11:56:34.672Z",
"details": [
{
"id": 0,
"visit_id": 0,
"service_variant": "string",
"cargo_num_pack": 0,
"cargo_weight": 0,
"terminal_code": "string",
"receiver_name": "string",
"receiver_street": "string",
"receiver_contact_fio": "string",
"receiver_contact_phone": "string",
"delivery_city_id": 0,
"is_deleted": true
}
]
},
"shipments": [
{
"id": 0,
"visit_id": 0,
"status": 0,
"status_name": "string",
"organization": {
"id": 0,
"name": "string"
},
"source": {
"id": 0,
"region_id": 0,
"region_name": "string",
"area_id": 0,

"area name": "string",

area_name : string,
"address": "string",
"home": "string",
"latitude": 0,
"longitude": 0
},
"destination": {
"id": 0,
"region_id": 0,
"region_name": "string",
"area_id": 0,
"area_name": "string",
"address": "string",
"home": "string",
"latitude": 0,
"longitude": 0
},
"number_of_boxes": 0,
"number_of_drugs": 0,
"weight": 0,
"price_per_box": 0,
"price_per_km": 0,
"distance": 0,
"delivery_time": 0,
"date_of_creation":
"2026-04-14T11:56:34.672Z",
"delivery_scheduled": true,
"ready": true,
"comment": "string"
}
]
}
]

#### _N__o__li__n__k__s_

#### Parameters TryitoutName Description

### delive ryId *

integer($int32)

_(path)_

#### Responses

#### L i n k s _N__o__li__n__k__s__N__o__li__n__k__s_

#### _N__o__li__n__k__s__N__o__li__n__k__s_

### /Delivery /types

#### Parameters

#### Tryitout No parameters Responses

#### L i n k s _N__o__li__n__k__s__N__o__li__n__k__s_

### /Delivery /options

#### Parameters Tryitout No parameters Responses

#### L i n k s _N__o__li__n__k__s__N__o__li__n__k__s_

#### _o__li__n__k__s_
## Logistics

####
GET
### /Logistics /cars

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Logistics /drivers

#### Parameters Tryitout No parameters

#### Responses

#### L i n k s

### /Logistics /storages

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### _o__li__n__k__s_
## Shipments

####
POST
### /Shipments

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Shipments

#### Parameters

#### Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

### shipm entId *

integer
($int32
)

_(path)_

"weight": 0,
"price_per_box": 0,
"price_per_km": 0
}

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### shipm entId *

integer
($int32
)

_(path)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### shipm entId *

integer
($int32
)

_(path)_

### storag eId *

integer
($int32
)

_(path)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### shipm entId *

integer
($int32
)

_(path)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### shipm entId *

integer
($int32
)

_(path)_

"number_of_boxes": 0,
"weight": 0,
"price_per_box": 0,
"price_per_km": 0,
"distance": 0
}

#### Responses

#### L i n k s

#### _o__li__n__k__s_
### Schemas

### ShipmentRequest{

Servers
#### /api

## DayType

####
GET
### /DayType

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /DayType /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### i n k s

#### _o__li__n__k__s_
## WorkDay

####
GET
### /WorkDay /status

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /WorkDay /start

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /WorkDay /end

#### Parameters Tryitout No parameters

#### Responses

#### L i n k s

### /WorkDay

#### Parameters Tryitout

### start_datestring($
date-time)

_(que_
_ry)_

### end_datestring($
date-time)

_(que_
_ry)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
### Schemashttps://dev.lima.uz/swagger/index.html?urls.primaryName=Visits.API%20-%201.0

Servers
#### /api Authorize

## ExpenseOrder

####
POST
### /ExpenseOrder

#### Parameters

#### Tryitout No parameters Responses

#### L i n k s

#### _o__li__n__k__s_
## Markups

#### Parameters TryitoutName Description

_(path)_

#### Responses

#### L i n k s

##### автоматически фильтрует по тенанту.

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters Tryitout NoparametersRequestbody

"id": 0,
"payment_variant_id": 0,
"sum_start": 0,
"sum_end": 0,
"margin_percent": 0,
"is_wholesaler": true,
"is_deleted": true
}
]
}

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters Tryitout No parameters

{
"drug_id": 0,
"margin_percent": 0
}
]

#### Responses

#### L i n k s

### /Markups /short

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Markups /sync

#### Parameters TryitoutName Description

### sync _idinteger(
$int
64)

_(que_
_ry)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
## Orders

####
GET Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### start_datestring($date-time)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### org_namestring

_(quer_
_y)_

### regio n_idinteger($int32)

_(quer_
_y)_

### area _Idinteger($int32)

_(quer_
_y)_

### doc_namestring

_(quer_
_y)_

### doc_ idinteger($int32)

_(quer_
_y)_

### phon e

string

_(quer_
_y)_

### doc_ posstring

_(quer_
_y)_

### sale s

array

[number]

_(quer_
_y)_

### prepaymentsarray

[number]

_(quer_
_y)_

### type _idarray

[integer]

_(quer_
_y)_

_(quer_
_y)_

### order_statusstring($byte)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### company_idinteger($int32)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

#### Responses

#### L i n k s

### /Orders /reporting-v2

#### Parameters TryitoutName Description

_(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### start_datestring($date-time)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### org_namestring

_(quer_
_y)_

### regio n_idinteger($int32)

_(quer_
_y)_

### area _Idinteger($int32)

_(quer_
_y)_

### doc_namestring

_(quer_
_y)_

### doc_ idinteger($int32)

_(quer_
_y)_

### phon e

string

_(quer_
_y)_

### doc_ posstring

_(quer_
_y)_

### sale s

array

[number]

_(quer_
_y)_

### prepaymentsarray

[number]

_(quer_
_y)_

### type _idarray

[integer]

_(quer_
_y)_

_(quer_
_y)_

### order_statusstring($byte)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### company_idinteger($int32)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### start_datestring($date-time)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### org_namestring

_(quer_
_y)_

### regio n_idinteger($int32)

_(quer_
_y)_

### area _Idinteger($int32)

_(quer_
_y)_

### doc_namestring

_(quer_
_y)_

### doc_ idinteger($int32)

_(quer_
_y)_

### phon e

string

_(quer_
_y)_

### doc_ posstring

_(quer_
_y)_

### sale s

array

[number]

_(quer_
_y)_

### prepaymentsarray

[number]

_(quer_
_y)_

### type _idarray

[integer]

_(quer_
_y)_

_(quer_
_y)_

### order_statusstring($byte)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### company_idinteger($int32)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### start_datestring($date-time)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### org_namestring

_(quer_
_y)_

### regio n_idinteger($int32)

_(quer_
_y)_

### area _Idinteger($int32)

_(quer_
_y)_

### doc_namestring

_(quer_
_y)_

### doc_ idinteger($int32)

_(quer_
_y)_

### phon e

string

_(quer_
_y)_

### doc_ posstring

_(quer_
_y)_

### sale s

array

[number]

_(quer_
_y)_

### prepaymentsarray

[number]

_(quer_
_y)_

### type _idarray

[integer]

_(quer_
_y)_

_(quer_
_y)_

### order_statusstring($byte)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### company_idinteger($int32)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### start_datestring($date-time)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### org_namestring

_(quer_
_y)_

### regio n_idinteger($int32)

_(quer_
_y)_

### area _Idinteger($int32)

_(quer_
_y)_

### doc_namestring

_(quer_
_y)_

### doc_ idinteger($int32)

_(quer_
_y)_

### phon e

string

_(quer_
_y)_

### doc_ posstring

_(quer_
_y)_

### sale s

array

[number]

_(quer_
_y)_

### prepaymentsarray

[number]

_(quer_
_y)_

### type _idarray

[integer]

_(quer_
_y)_

_(quer_
_y)_

### order_statusstring($byte)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### company_idinteger($int32)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### start_datestring($date-time)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### org_namestring

_(quer_
_y)_

### regio n_idinteger($int32)

_(quer_
_y)_

### area _Idinteger($int32)

_(quer_
_y)_

### doc_namestring

_(quer_
_y)_

### doc_ idinteger($int32)

_(quer_
_y)_

### phon e

string

_(quer_
_y)_

### doc_ posstring

_(quer_
_y)_

### sale s

array

[number]

_(quer_
_y)_

### prepaymentsarray

[number]

_(quer_
_y)_

### type _idarray

[integer]

_(quer_
_y)_

_(quer_
_y)_

### order_statusstring($byte)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### company_idinteger($int32)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### start_datestring($date-time)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### org_namestring

_(quer_
_y)_

### regio n_idinteger($int32)

_(quer_
_y)_

### area _Idinteger($int32)

_(quer_
_y)_

### doc_namestring

_(quer_
_y)_

### doc_ idinteger($int32)

_(quer_
_y)_

### phon e

string

_(quer_
_y)_

### doc_ posstring

_(quer_
_y)_

### sale s

array

[number]

_(quer_
_y)_

### prepaymentsarray

[number]

_(quer_
_y)_

### type _idarray

[integer]

_(quer_
_y)_

_(quer_
_y)_

### order_statusstring($byte)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### company_idinteger($int32)

_(quer_
_y)_

#### Responses

#### L i n k s

### /Orders /shipments

#### Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### start_datestring($date-time)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### org_namestring

_(quer_
_y)_

### regio n_idinteger($int32)

_(quer_
_y)_

### area _Idinteger($int32)

_(quer_
_y)_

### doc_namestring

_(quer_
_y)_

### doc_ idinteger($int32)

_(quer_
_y)_

### phon e

string

_(quer_
_y)_

### doc_ posstring

_(quer_
_y)_

### sale s

array

[number]

_(quer_
_y)_

### prepaymentsarray

[number]

_(quer_
_y)_

### type _idarray

[integer]

_(quer_
_y)_

_(quer_
_y)_

### order_statusstring($byte)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### company_idinteger($int32)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path_
_)_

#### Responses

#### L i n k s

### /Orders /add

##### Создание заявки вручную.

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path_
_)_

"order_comment": "string",
"drugs": [
{
"visit_detailing_id": 0,
"income_detailing_id": 0,
"drug_id": 0,
"drug_one_c_guid": "string",
"package": 0,
"margin_percent": 0,
"sale_price": 0,
"sale_price_without_nds": 0,
"serial_no": "string",
"expire_date": "2026-04-14T11:43:42.571Z",
"is_deleted": true,
"storage_id": "string"
}
],
"temp_drugs": [
{
"drug_id": 0,
"producer_id": 0,
"income_price": 0,
"base_price": 0,
"sale_price": 0,
"nds_percent": 0,
"serial_no": "string",
"drugs_count": 0
}
]
}

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### order Id *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

##### Замена контрагента в заявке.

#### Parameters TryitoutName Description

### order Id *

integer($int32)

_(path_
_)_

### orgId *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### order Id *

integer($int32)

_(path_
_)_

### date *

string($date-time)

_(path_
_)_

#### Responses

#### L i n k s

### /Orders /deferred

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### order Id *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### order Id *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### order Id *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

##### Изменение статуса заявки на "Заявка скомплектована".

#### Parameters TryitoutName Description

### order Id *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### order Id *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### order Id *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### order Id *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### order Id *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

##### Изменение статуса заявки на "Отменена".

#### Parameters TryitoutName Description

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(que_
_ry)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
## Pricing

#### Parameters Tryitout No parameters

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters

#### клиента. Responses

#### L i n k s

#### _o__li__n__k__s_
## Visits

####
GET

#### Parameters TryitoutName Description

### visitI d *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path_
_)_

],
"talked_about_drugs": [
{
"drug_id": 0,
"status_id": 0,
"comment": "string",
"ball": 0,
"document_ids": [
0
]
}
],
"drugs": [
{
"visit_detailing_id": 0,
"income_detailing_id": 0,
"drug_id": 0,
"drug_one_c_guid": "string",
"package": 0,
"margin_percent": 0,
"sale_price": 0,
"sale_price_without_nds": 0,
"serial_no": "string",
"expire_date": "2026-04-14T11:43:42.582Z",
"is_deleted": true,
"storage_id": "string"
}
],
"visit_pharm_circle": {
"pharmacist_names": "string",
"start": "2026-04-14T11:43:42.582Z",
"end": "2026-04-14T11:43:42.582Z",
"number_of_participants": 0
}
}

#### Responses

#### L i n k s

#### Parameters Tryitout

### dat e

string($
date-time)

_(que_
_ry)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutNameDescription

### start_datestring($
date-time)

_(que_
_ry)_

### end_datestring($
date-time)

_(que_
_ry)_

### medrep_idarray[integer]

_(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### start_datestring($date-time)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### org_namestring

_(quer_
_y)_

### regio n_idinteger($int32)

_(quer_
_y)_

### area _Idinteger($int32)

_(quer_
_y)_

### doc_namestring

_(quer_
_y)_

### doc_ idinteger($int32)

_(quer_
_y)_

### phon e

string

_(quer_
_y)_

### doc_ posstring

_(quer_
_y)_

### sale s

array

[number]

_(quer_
_y)_

### prepaymentsarray

[number]

_(quer_
_y)_

### type _idarray

[integer]

_(quer_
_y)_

_(quer_
_y)_

### order_statusstring($byte)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### company_idinteger($int32)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### start_datestring($date-time)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### org_namestring

_(quer_
_y)_

### regio n_idinteger($int32)

_(quer_
_y)_

### area _Idinteger($int32)

_(quer_
_y)_

### doc_namestring

_(quer_
_y)_

### doc_ idinteger($int32)

_(quer_
_y)_

### phon e

string

_(quer_
_y)_

### doc_ posstring

_(quer_
_y)_

### sale s

array

[number]

_(quer_
_y)_

### prepaymentsarray

[number]

_(quer_
_y)_

### type _idarray

[integer]

_(quer_
_y)_

_(quer_
_y)_

### order_statusstring($byte)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### company_idinteger($int32)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### start_datestring($date-time)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### org_namestring

_(quer_
_y)_

### regio n_idinteger($int32)

_(quer_
_y)_

### area _Idinteger($int32)

_(quer_
_y)_

### doc_namestring

_(quer_
_y)_

### doc_ idinteger($int32)

_(quer_
_y)_

### phon e

string

_(quer_
_y)_

### doc_ posstring

_(quer_
_y)_

### sale s

array

[number]

_(quer_
_y)_

### prepaymentsarray

[number]

_(quer_
_y)_

### type _idarray

[integer]

_(quer_
_y)_

_(quer_
_y)_

### order_statusstring($byte)

_(quer_
_y)_

_(quer_
_y)_

_(quer_
_y)_

### company_idinteger($int32)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters

0
],
"manager_ids": [
0
],
"talked_about_drugs": [
{
"drug_id": 0,
"status_id": 0,
"comment": "string",
"ball": 0,
"document_ids": [
0
]
}
],
"drugs": [
{
"visit_detailing_id": 0,
"income_detailing_id": 0,
"drug_id": 0,
"drug_one_c_guid": "string",
"package": 0,
"margin_percent": 0,
"sale_price": 0,
"sale_price_without_nds": 0,
"serial_no": "string",
"expire_date": "2026-04-14T11:43:42.601Z",
"is_deleted": true,
"storage_id": "string"
}
],
"visit_pharm_circle": {
"pharmacist_names": "string",
"start": "2026-04-14T11:43:42.601Z",
"end": "2026-04-14T11:43:42.601Z",
"number_of_participants": 0
}
}

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

### visitI d *

integer($int32)

_(path_
_)_

### form atstring

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters Tryitout

_(que_
_ry)_

"med_rep_id": 0,
"order_user_id": 0,
"payback_date": "2026-04-14T11:43:42.605Z",
"order_expire_date": "2026-04-14T11:43:42.605Z",
"start_date": "2026-04-14T11:43:42.605Z",
"end_date": "2026-04-14T11:43:42.605Z",
"latitude": 0,
"longitude": 0,
"payment_variant_id": 0,
"margin_id": 0,
"company_id": 0,
"contract_id": 0,
"doctor_ids": [
0
],
"manager_ids": [
0
],
"talked_about_drugs": [
{
"drug_id": 0,
"status_id": 0,
"comment": "string",
"ball": 0,
"document_ids": [
0
]
}
],
"drugs": [
{
"visit_detailing_id": 0,
"income_detailing_id": 0,
"drug_id": 0,
"drug_one_c_guid": "string",
"package": 0,
"margin_percent": 0,
"sale_price": 0,
"sale_price_without_nds": 0,
"serial_no": "string",
"expire_date": "2026-04-14T11:43:42.605Z",
"is_deleted": true,
"storage_id": "string"
}

],
"visit_pharm_circle": {
"pharmacist_names": "string",
"start": "2026-04-14T11:43:42.605Z",
"end": "2026-04-14T11:43:42.605Z",
"number_of_participants": 0
}
}

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### organiz ationId *

integer(
$int32)

_(path)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(que_
_ry)_

#### Responses

#### L i n k s

### /Visits /formats

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### _o__li__n__k__s_
### Schemas

}

}

}

`Правила` `заполнения` `диапазонов` ( `валидируются` `в`
MarkupsService):

}

}

### VisitTypeinteger($int32)

https://dev.lima.uz/swagger/index.html?
urls.primaryName=Company.API%20-%201.0

Servers
#### /api

## Company

#### Authorize

####
POST Parameters

#### Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

##### областях.

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters Tryitout No parameters

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters

}

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

"company_id": 2147483647,
"markup_detailings": [
{
"id": 0,
"payment_variant_id": 2,
"sum_start": 0,
"sum_end": 0,
"margin_percent": 0,
"is_wholesaler": true,
"is_deleted": true
}
]
}

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query_
_)_

_(query_
_)_

_(query_
_)_

_(query_
_)_

_(query_
_)_

_(query_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

_(path)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### _o__li__n__k__s_
### SchemasServers
#### /api

## Payments

####
POST
### /Payments

#### Parameters Tryitout No parameters

"payment_type": 0,
"payment_variant": 0,
"sum": 0.01,
"comment": "string"
}

#### Responses

#### L i n k s

### /Payments

#### Parameters TryitoutName Description

### page_numberinteger(
$int
32)

_(que_
_ry)_

### page_sizeinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s

### /Payments /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Payments /types

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Payments /variants

#### Parameters

#### Tryitout No parameters Responses

#### L i n k s

### /Payments /statistics

#### Parameters TryitoutName Description

### clien t_idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### client Id *

integer($int32)

_(path_
_)_

### date_ fromstring($date-time)

_(quer_
_y)_

### date_ tostring($date-time)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### client Id *

integer($int32)

_(path_
_)_

### date_ fromstring($date-time)

_(quer_
_y)_

### date_ tostring($date-time)

_(quer_
_y)_

#### Responses

#### L i n k s _N__o__li__n__k__s_

Servers
#### /api

## Account

####
POST
### /Account /authorize

#### Parameters Tryitout

#### No parameters Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Account /check

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Account /permissions

#### Parameters Tryitout No parameters

#### Responses

#### L i n k s

### /Account /create

#### Parameters Tryitout No parameters

"id": 0,
"name": "string"
}
],
"role": {
"role_id": 0,
"role_name": "string",
"is_deleted": true,
"desc": "string",
"ignore_company_filter": true
}
}

#### Responses

#### L i n k s

### /Account /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### userI d *

integer($int32)

_(path_
_)_

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Account /all

#### Parameters TryitoutName Description

### company_idinteger(
$int
32)

_(que_
_ry)_

### pag e

integer(
$int
32)

_(que_
_ry)_

### region_idinteger(
$int
32)

_(que_
_ry)_

### role _idinteger(
$int
32)

_(que_
_ry)_

_(que_
_ry)_

### sear chstring

_(que_
_ry)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
## Grants

####
GET
### /Grants

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### _o__li__n__k__s_

## Online

####
PUT
### /Online

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### _o__li__n__k__s_
## Roles

####
GET
### /Roles

#### Parameters Tryitout No parameters

#### Responses

#### L i n k s

### /Roles

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

### roleI d *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### roleId *

integer($int32)

_(path)_

_(path)_

#### Responses

#### L i n k s

### /Roles /{roleId}

#### Parameters TryitoutName Description

### roleI d *

integer($int32)

_(path_
_)_

#### Responses

#### i n k s

### /Roles /hierarchy

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Roles /hierarchy

#### Parameters Tryitout** NoparametersRequestbodyapplication/jsontext/jsonapplication/*+json

#### Responses

#### L i n k s

### /Roles /hierarchy

#### Parameters Tryitout No parameters

}

#### Responses

#### L i n k s

#### _o__li__n__k__s_
## Users

####
GET
### /Users

#### Parameters TryitoutName Description

### nam e

string

_(que_
_ry)_

_(que_
_ry)_

_(que_
_ry)_

### region_idinteger(
$int
32)

_(que_
_ry)_

_(que_
_ry)_

### company_idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s

### /Users /me

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Users /for-view

#### Parameters TryitoutName Description

### region_idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s

### /Users /company

#### Parameters TryitoutName Description

### nam e

string

_(que_
_ry)_

_(que_
_ry)_

_(que_
_ry)_

### region_idinteger(
$int
32)

_(que_
_ry)_

_(que_
_ry)_

### company_idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s

### /Users /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Users /find /{name}

#### Parameters TryitoutName Description

### nam e *

string

_(path_
_)_

_(quer_
_y)_

### regio n_idinteger($int32)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### telegramIdinteger(
$int
64)

_(que_
_ry)_

#### Responses

#### L i n k s

### /Users /operators

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters Tryitout No parameters

],
"user_ids": [
0
]
}

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### _o__li__n__k__s_

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### _o__li__n__k__s_
### Schemas

[/swagger/docs/1.0/warehouse](https://dev.lima.uz/swagger/docs/1.0/warehouse)

Servers
#### /api

## Contracts

#### Authorize

####
POST
### /Contracts /add

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Contracts /batch

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

### client Inn *

integer($int64)

_(path)_

### company_idinteger($int32)

_(query_
_)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
## Expenses

####
POST
### /Expenses

#### Parameters Tryitout No parameters

#### Responses

#### L i n k s

### /Expenses

#### Parameters TryitoutName Description

### page_numberinteger(
$int
32)

_(que_
_ry)_

### page_sizeinteger(
$int
32)

_(que_
_ry)_

_(que_
_ry)_

### type _idinteger(
$int
32)

_(que_
_ry)_

### quer y

string

_(que_
_ry)_

### date_fromstring($
date-time)

_(que_
_ry)_

### date _tostring($
date-time)

_(que_
_ry)_

### clien t_idarray[integer]

_(que_
_ry)_

### user _idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s

### /Expenses /batch

#### Parameters Tryitout No parameters

}
]
}

#### Responses

#### L i n k s

### /Expenses /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Expenses /types

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Expenses /statistics

#### Parameters Tryitout No parameters Responses

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### client Id *

integer($int32)

_(path_
_)_

### date_ fromstring($date-time)

_(quer_
_y)_

#### L i n k s

### date_ tostring($date-time)

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### client Id *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### clien t_idinteger(
$int
32)

_(que_
_ry)_

### date_fromstring($
date-time)

_(que_
_ry)_

### date _tostring($
date-time)

_(que_
_ry)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### clien t_idinteger(
$int
32)

_(que_
_ry)_

### date_fromstring($
date-time)

_(que_
_ry)_

### date _tostring($
date-time)

_(que_
_ry)_

#### Responses

#### L i n k s

#### _li_ _s_

####
POST
### /Incomes

#### Parameters Tryitout No parameters

"details": [
{
"drug_id": 0,
"producer_id": 0,
"amount": 0,
"expire_date": "2026-04-14T11:48:40.883Z",
"serial_number": "string",
"base_price": 0,
"sale_price": 0,
"nds": 0,
"margin_percent": 0
}
]
}

#### Responses

#### L i n k s

### /Incomes

#### Parameters TryitoutName Description

### page_numberinteger(
$int
32)

_(que_
_ry)_

### page_sizeinteger(
$int
32)

_(que_
_ry)_

_(que_
_ry)_

### quer y

string

_(que_
_ry)_

### date_fromstring($
date-time)

_(que_
_ry)_

### date _tostring($
date-time)

_(que_
_ry)_

### supplier_idarray[integer]

_(que_
_ry)_

_(que_
_ry)_

#### Responses

#### L i n k s

### /Incomes /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

"process_immediately": true,
"is_draft": true,
"date_of_creation": "2026-04-14T11:48:40.884Z",
"details": [
{
"drug_id": 0,
"producer_id": 0,
"amount": 0,
"expire_date": "2026-04-14T11:48:40.884Z",
"serial_number": "string",
"base_price": 0,
"sale_price": 0,
"nds": 0,
"margin_percent": 0
}
]
}

#### Responses

#### L i n k s

### /Incomes /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Incomes /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Incomes /types

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Incomes /types

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Incomes /statistics

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### Parameters

#### Tryitout No parameters Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters Tryitout NoparametersRequestbodymultipart/form-data

### Namestring

### DateOfCreati onstring($date-time)

### ColumnMappi ng.StartRowinteger($int3
2)

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters

#### _N__o__li__n__k__s_

"period": "2026-04-14T11:48:40.890Z",
"data": [
{
"drug_id": 0,
"drug_guid": "string",
"serial_number": "string",
"base_price": 0
}
]
}

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### drugI d *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
## Returns

####
POST
### /Returns /from-client

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Returns /to-supplier

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Returns /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Returns

#### Parameters TryitoutName Description

### page_numberinteger($int32)

_(quer_
_y)_

### page _sizeinteger($int32)

_(quer_
_y)_

_(quer_
_y)_

### return_type_idinteger($int32)

_(quer_
_y)_

### expense_idinteger($int32)

_(quer_
_y)_

### income_idinteger($int32)

_(quer_
_y)_

### storage_idinteger($int32)

_(quer_
_y)_

### quer y

string

_(quer_
_y)_

### date_fromstring($date-time)

_(quer_
_y)_

### date _tostring($date-time)

_(quer_
_y)_

### organization_idarray

[integer]

_(quer_
_y)_

#### Responses

#### L i n k s

### /Returns /types

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Returns /statistics

#### Parameters Tryitout No parameters Responses

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### L i n k s

#### _o__li__n__k__s_
## Stock

####
GET
### /Stock /current

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

### drug_i d

array[integer]

_(query)_

_(query)_

_(query)_

### expire _datestring(
$date-time)

_(query)_

### storag e_idinteger
($int32
)

_(query)_

### produc er_idinteger
($int32
)

_(query)_

### income _datestring(
$date-time)

_(query)_

### Compa nyIdinteger
($int32
)

_(query)_

### StorageRegionIdinteger
($int32
)

_(query)_

_(query)_

#### Responses

#### L i n k s

#### _N__o__li__n__k__s_

####
GET
### /Stock /price-list

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

### drug_i d

array[integer]

_(query)_

_(query)_

_(query)_

### expire _datestring(
$date-time)

_(query)_

### storag e_idinteger
($int32
)

_(query)_

### produc er_idinteger
($int32
)

_(query)_

### income _datestring(
$date-time)

_(query)_

### Compa nyIdinteger
($int32
)

_(query)_

### StorageRegionIdinteger
($int32
)

_(query)_

_(query)_

#### Responses

#### L i n k s

#### _N__o__li__n__k__s_

####
PUT
### /Stock

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### _o__li__n__k__s_

#### Parameters TryitoutName Description

### date_fromstring($
date-time)

_(que_
_ry)_

### date _tostring($
date-time)

_(que_
_ry)_

### storage_idinteger(
$int
32)

_(que_
_ry)_

### drug _idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### L i n k s _N__o__li__n_

{
"summary": [
{
"common": {
"drug": {
"id": 0,
"drug_id": 0,
"drug_guid": "string",
"name": "string",
"quantity": 0,
"photo": {
"small_url": "string",
"middle_url": "string"
}
},
"initial_balance": 0,
"total_income": 0,
"total_expense": 0,
"total_return": 0,
"final_balance": 0,
"total_income_sum": 0,
"total_expense_sum": 0,
"total_return_sum": 0,
"final_balance_sum": 0
},
"warehouse": [
{
"storage_id": 0,
"storage_name": "string",
"initial_balance": 0,
"total_income": 0,
"total_expense": 0,
"total_return": 0,
"final_balance": 0,
"total_income_sum": 0,
"total_expense_sum": 0,
"total_return_sum": 0,
"final_balance_sum": 0
}
],
"details": [
{

"operation date":

#### _n__k__s_operation_date :
"2026-04-14T11:48:40.897Z",
"operation_type": "string",
"document_id": 0,
"document_name": "string",
"storage_id": 0,
"storage_name": "string",
"drug": {
"id": 0,
"drug_id": 0,
"drug_guid": "string",
"name": "string",
"quantity": 0,
"photo": {
"small_url": "string",
"middle_url": "string"
}
},
"income_amount": 0,
"expense_amount": 0,
"return_amount": 0,
"sale_price": 0,
"supplier_id": 0,
"supplier_name": "string",
"client_id": 0,
"client_name": "string",
"final_balance": 0
}
]
}
]
}
####
GET
### /Stock /statistics

#### Parameters Tryitout No parameters Responses

#### Parameters TryitoutName Description

#### L i n k s

_(query)_

_(query)_

_(query)_

### drug_i d

array[integer]

_(query)_

_(query)_

_(query)_

### expire _datestring(
$date-time)

_(query)_

### storag e_idinteger
($int32
)

_(query)_

### produc er_idinteger
($int32
)

_(query)_

### income _datestring(
$date-time)

_(query)_

### Compa nyIdinteger
($int32
)

_(query)_

### StorageRegionIdinteger
($int32
)

_(query)_

_(query)_

_(query)_

#### Responses

#### Parameters TryitoutName Description

### document_typeinteger($int32)

_(quer_
_y)_

#### L i n k s

### date_fromstring($date-time)

_(quer_
_y)_

### date _tostring($date-time)

_(quer_
_y)_

### counterparty_idarray

[integer]

_(quer_
_y)_

### statu s_idinteger($int32)

_(quer_
_y)_

### quer y

string

_(quer_
_y)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### document_typeinteger($int32)

_(quer_
_y)_

### date_fromstring($date-time)

_(quer_
_y)_

### date _tostring($date-time)

_(quer_
_y)_

### counterparty_idarray

[integer]

_(quer_
_y)_

### statu s_idinteger($int32)

_(quer_
_y)_

### quer y

string

_(quer_
_y)_

#### Responses

#### Parameters TryitoutName Description

#### L i n k s

### date_fromstring($
date-time)

_(que_
_ry)_

### date _tostring($
date-time)

_(que_
_ry)_

### storage_idinteger(
$int
32)

_(que_
_ry)_

### drug _idinteger(
$int
32)

_(que_
_ry)_

#### Responses

#### Parameters TryitoutName Description

### sync _idinteger(
$int
64)

_(que_
_ry)_

#### Responses

#### L i n k s L i n k s

#### _o__li__n__k__s_
## Storages

####
GET
### /Storages

#### Parameters TryitoutName Description

_(quer_
_y)_

_(quer_
_y)_

### storage_type_idinteger($int32)

_(quer_
_y)_

_(quer_
_y)_

#### Responses

#### L i n k s

### /Storages

#### Parameters Tryitout NoparametersRequestbodyapplication/jsontext/jsonapplication/*+json

#### Responses

#### L i n k s

### /Storages /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Storages /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

### /Storages /types

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Storages /types

#### Parameters Tryitout No parameters

{
"name": "string"
}

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
### Schemas

}

drugServers
#### /api

## Global

#### Authorize

####
GET
### /Global

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Global

#### Parameters Tryitout No parameters

#### Responses

#### L i n k s

### /Global /{key}

#### Parameters Tryitout

### key ***

string

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### comp anyId *

integer
($int32
)

_(path)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### comp anyId *

integer
($int32
)

_(path)_

#### Responses

#### L i n k s

### /Global /company /{companyId} /{key}

#### Parameters TryitoutName Description

### comp anyId *

integer
($int32
)

_(path)_

_(path)_

#### Responses

#### L i n k s

#### _o__li__n__k__s_
### SchemasServers
#### /api

## Cart

####
GET
### /Cart

#### Parameters Tryitout No parameters

#### Responses

#### L i n k s

### /Cart

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Cart /items

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Cart /count

#### Parameters Tryitout No parameters

#### Responses

#### L i n k s

### /Cart /{id}

#### Parameters TryitoutName Description

_(pat_
_h)_

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

### itemI d *

integer($int32)

_(path_
_)_

#### Responses

#### L i n k s

#### Parameters Tryitout No parameters Responses

#### L i n k s

### /Cart /items /grouped

#### Parameters Tryitout No parameters Responses

#### L i n k s

#### _o__li__n__k__s_
### SchemasServers
#### /api Authorize

## Reports

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

_(query)_

Id района.

Id товара, по которому нужно получить данные.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

#### Responses

#### L i n k s

#### Parameters TryitoutName Description

_(query)_

_(query)_

_(query)_

Id района.

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

Id товара, по которому нужно получить данные.

Тип организации. 1 - аптека, 2 - ЛПУ, 3 - дистрибьютер

_(query)_

_(query)_

_(query)_

_(query)_

_(query)_

### Uniqueboolean

_(query)_

Id организации.

Фильтрация данных по уникальности.

#### --truefalse

_(query)_

#### Responses**

#### https: // dev.li ma.u z/ swag ger/ index .html ? urls.primaryName= Stora ge.A PI%2 0- %201 .0

