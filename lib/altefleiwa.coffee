# Description:
#   Serves the menu for the Dieckert Cantina.
#
# Commands:
#   hubot feed me [<day>] - Replys with the day's menu or today's menu, if no day was specified.
#
# Notes:
#   This script currently only supports the Alte Fleiwa run by Dieckert.
#   The plan is requested from http://www.speisereise.com/content/speise/kantine_speiseplan.php.
#
# Author:
#   sgade

http = require 'http'
cheerio = require 'cheerio'
entities = require('html-entities').AllHtmlEntities
iconv = new require 'iconv-lite'

planEncoding = "CP1252"
planURL = "http://www.speisereise.com/content/speise/kantine_speiseplan.php"

module.exports = (robot) ->

  # Fetches and returns the plan's binary buffer data for the given calendar week.
  getPlan = (calendarWeek, cb) ->
    # We have our own http implementation because of encoding issues
    # request the page
    http.get planURLForCalendarWeek(calendarWeek), (res) ->
      body = null
      # save all parts of the page
      res.on 'data', (bodyPart) ->
        partBuffer = new Buffer(bodyPart, planEncoding)
        if not body?
          body = partBuffer
        else
          body = Buffer.concat( [ body, partBuffer ] )
      # only call callback when all data is collected
      res.on 'end', ->
        cb null, res, body
      # call callback on error
      res.on 'error', (err) ->
        cb err, res, null

  # Returns the plan URL for the given calendar week.
  planURLForCalendarWeek = (calendarWeek) ->
    planURL + "?kw=#{ calendarWeek }"

  # HUBOT FEED ME
  robot.respond /feed me ?(today|tomorrow|mon|tue|wed|thu|fri)?/i, (res) ->

    day = res.match[1]
    dayOfWeek = textToDayOfWeek day

    if not day? or /today/i.test(day)
      dayOfWeek = new Date().getDay()
    else if /tomorrow/i.test(day)
      dayOfWeek = ( new Date().getDay() + 1 ) % 7
    
    replyForDayOfWeek dayOfWeek, res

  # Replys for a "feed me" request for the given day of the week.
  replyForDayOfWeek = (dayOfWeek, res) ->
    if dayOfWeek < 1 || dayOfWeek > 5
      res.reply "I'm sorry, food is only served during the week."
      return

    requestCalendarWeek = getCurrentCalendarWeek()
    todayDayOfWeek = new Date().getDay()
    if todayDayOfWeek > dayOfWeek
      # the requested day is in the past
      # so take the next week
      requestCalendarWeek += 1

    getPlan requestCalendarWeek, (err, response, body) ->
      if err?
        res.reply "I'm sorry, I could not get the plan for #{ getTextForDayOfWeek(dayOfWeek) }.\nPlease try again in a little while."
        return

      body = iconv.decode body, planEncoding
      $ = cheerio.load body
      tds = $ "td.speiseplan"

      meals = getMealsForDay dayOfWeek, tds
      mealDescriptions = getMealDescriptions $

      text = ""
      if meals.length == 0
        text = "There are no meals offered for #{ getTextForDayOfWeek(dayOfWeek) }."
      else
        text = "#{ getTextForDayOfWeek(dayOfWeek) }'s meals:\n"
        for i in [0...meals.length]
          text += "--- #{ mealDescriptions[i] } ---\n#{ meals[i] }"
      text = text.trim()

      res.reply text

  # Filters the given TD-Elements for the given day of the week and returns their text values.
  getMealsForDay = (dayOfWeek, tds) ->
    meals = []

    dayTds = tds.slice ( dayOfWeek - 1 ) * 4, dayOfWeek * 4
    if dayTds.length == 0
      return meals

    for i in [0...dayTds.length]
      mealDescription = dayTds.eq(i).html().replace(/<br>/ig, "\n")
      mealDescription = entities.decode mealDescription
      meals.push mealDescription

    return meals

  getMealDescriptions = ($) ->
    descriptions = []

    tds = $ "td .speisebold"
    # don't slice here because the number of meals may vary

    for i in [0...tds.length]
      descriptions.push tds.eq(i).text()

    return descriptions

  # Transforms a text value into a number value corresponding to the Date-Object's .getDay().
  textToDayOfWeek = (text) ->
    if /mon(day)?/i.test(text)
      1
    else if /tue(sday)?/i.test(text)
      2
    else if /wed(nesday)?/i.test(text)
      3
    else if /thu(rsday)?/i.test(text)
      4
    else if /fri(day)?/i.test(text)
      5
    else if /sat(urday)?/i.test(text)
      6
    else if /sun(day)?/i.test(text)
      0
    else
      -1

  # Transforms a number value (e.g. from Date.getDay()) into its text representation.
  getTextForDayOfWeek = (dayOfWeek) ->
    today = new Date().getDay()
    if today == dayOfWeek
      "Today"
    else if (today+1)%7 == dayOfWeek
      "Tomorrow"
    else
      switch dayOfWeek
        when 0 then "Sunday"
        when 1 then "Monday"
        when 2 then "Tuesday"
        when 3 then "Wednesday"
        when 4 then "Thursday"
        when 5 then "Friday"
        when 6 then "Saturday"

  # Returns the calendar week today is in.
  getCurrentCalendarWeek = ->
    # taken from http://www.web-toolbox.net/webtoolbox/datum/code-kalenderwocheaktuell.htm
    now = new Date();
    thursdayDate = new Date(now.getTime() + (3-((now.getDay()+6) % 7)) * 86400000);
    cwYear = thursdayDate.getFullYear();
    thursdayCW = new Date(new Date(cwYear,0,4).getTime() + (3-((new Date(cwYear,0,4).getDay()+6) % 7)) * 86400000);

    Math.floor(1.5 + (thursdayDate.getTime() - thursdayCW.getTime()) / 86400000/7);
