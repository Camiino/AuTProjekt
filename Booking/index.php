<!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Book a Computer</title>

    <!-- FullCalendar JS (Version 6.1.15) -->
    <script src="https://cdn.jsdelivr.net/npm/fullcalendar@6.1.15/index.global.min.js"></script>
    <!-- jQuery (Version 3.7.1) -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js"></script>
    
    <!-- Link to External CSS -->
    <link rel="stylesheet" href="index.css">
  </head>
  <body>
    <div class="container">
      <!-- Calendar -->
      <div id="calendar"></div>
      <!-- Booking Form (Initially Greyed Out) -->
      <form id="bookingForm">
        <h2 style="text-align: center">Rechner Buchen</h2>
        <label for="pcSelect">Verfügbare Rechner:</label>
        <select id="pcSelect" required></select>
        <label for="user">Name:</label>
        <input type="text" id="user" required>
        <label for="email">Email:</label>
        <input type="text" id="email" required>
        <label for="start_time">Beginn Zeit:</label>
        <input type="datetime-local" id="start_time" required>
        <label for="end_time">End Zeit:</label>
        <input type="datetime-local" id="end_time" required>
        <button type="submit">Buchen</button>
      </form>
    </div>

    <!-- Overlay Popup -->
    <div id="overlay">
      <div class="overlay-content">
        <h2>Buchungsdetails</h2>
          <div class="content-display">
          <h2 id="overlayTitle">Name:</h2>
          <p id="overlayName"></p>

          <h2 id="overlayTitle">Email:</h2>
          <p id="overlayEmail"></p>

          <h2 id="overlayTitle">Rechner:</h2>
          <p id="overlayComputer"></p>

          <h2 id="overlayTitle">Buchung:</h2>
          <p id="overlayTime"></p>

          <button onclick="document.getElementById('overlay').style.display='none'" class="close-btn">Schließen</button>
        </div>
      </div>
    </div>

    <script>
      document.addEventListener("DOMContentLoaded", async function() {
        var calendarEl = document.getElementById('calendar');
        var selectedStartDate = null;
        var selectedEndDate = null;
        var allComputers = [];       // Fetched from API
        var bookingsData = [];       // Fetched from API
        var calendar;
        
        // ---------------- Helper Functions ----------------
        // Fetch computers from API
        async function fetchComputers() {
          try {
            let response = await fetch("http://localhost:5000/computers");
            let data = await response.json();
            console.log("Computers from DB:", data);
            return data.map(item => item.name);
          } catch (error) {
            console.error("Error fetching computers:", error);
            return [];
          }
        }
        
        // Fetch bookings from API
        async function fetchBookings() {
          try {
            let response = await fetch("http://localhost:5000/status");
            let data = await response.json();
            console.log("Raw booking data from API:", data);
            bookingsData = data;
            return data;
          } catch (error) {
            console.error("Error fetching bookings:", error);
          }
        }
        
  // Compute partially booked dates for display
  function computePartialBookedDates(bookings) {
    const dates = new Set();
    bookings.forEach(booking => {
      let start = new Date(booking.start_time);
      let end = new Date(booking.end_time);
      // Subtract 1 day from both start and end for display purposes.
      start.setDate(start.getDate() - 1);
      end.setDate(end.getDate() - 1);
      let current = new Date(start);
      while (current <= end) {
        dates.add(current.toISOString().split("T")[0]);
        current.setDate(current.getDate() + 1);
      }
    });
    return Array.from(dates);
  }

      // Compute fully booked dates (full occupancy) for display
      function computeFullBlockedDates(bookings, computers) {
          const dateBookings = {};
          bookings.forEach(booking => {
              let start = new Date(booking.start_time);
              let end = new Date(booking.end_time);
              start.setDate(start.getDate() - 1);
              end.setDate(end.getDate() - 1);
              // Use the DB dates directly (assumed inclusive)
              let current = new Date(start);
              while (current <= end) {
              const dateStr = current.toISOString().split("T")[0];
              if (!dateBookings[dateStr]) {
                  dateBookings[dateStr] = new Set();
              }
              dateBookings[dateStr].add(booking.computer_name);
              current.setDate(current.getDate() + 1);
              }
          });
          const fullBlocked = [];
          for (let date in dateBookings) {
              if (dateBookings[date].size >= computers.length) {
              fullBlocked.push(date);
              }
          }
          return fullBlocked;
          }


        
        // Adjust the end date if a fully booked date is found in the range.
        function adjustEndDate(startDate, endDate, fullBlockedDates) {
          let current = new Date(startDate);
          let end = new Date(endDate);
          while (current <= end) {
            let dStr = current.toISOString().split("T")[0];
            if (fullBlockedDates.includes(dStr)) {
              let adjusted = new Date(current);
              // Here, if you want to shrink the selection, subtract 1 day.
              adjusted.setDate(adjusted.getDate());
              return adjusted.toISOString().split("T")[0];
            }
            current.setDate(current.getDate() + 1);
          }
          return endDate;
        }
        
        // Determine available PCs for the selected range.
        function getAvailablePCs(startDate, endDate) {
          let available = allComputers.slice();
          let sStart = new Date(startDate);
          let sEnd = new Date(endDate);

          // Adjust start date to match stored bookings (subtract 1 day)
          sEnd.setDate(sEnd.getDate() + 1);

          bookingsData.forEach(booking => {
              let bStart = new Date(booking.start_time);
              let bEnd = new Date(booking.end_time);

              if (sStart < bEnd && sEnd > bStart) {
                  available = available.filter(pc => pc !== booking.computer_name);
              }
          });

          console.log("Available computers from", startDate, "to", endDate, ":", available);
          return available;
      }

        
        // Update the PC select dropdown—list all PCs but disable those not available.
        function updateComputerSelect(startDate, endDate) {
            const pcSelect = document.getElementById("pcSelect");
            let previousSelection = pcSelect.value;  // Store previous selection

            pcSelect.innerHTML = "";  // Clear dropdown
            let available = getAvailablePCs(startDate, endDate);

            allComputers.forEach(pc => {
                let option = document.createElement("option");
                option.value = pc;
                option.textContent = pc;
                if (available.indexOf(pc) === -1) {
                    option.disabled = true;
                    option.textContent += " (booked)";
                }
                pcSelect.appendChild(option);
            });

            // Restore previous selection if it's still available
            if (available.includes(previousSelection)) {
                pcSelect.value = previousSelection;
            }
        }

        // ---------------- Calendar Initialization ----------------
        let selectedRange = null; // Store the selected range globally

        function initializeCalendar() {
      calendar = new FullCalendar.Calendar(calendarEl, {
          initialView: "dayGridMonth",
          locale: "de",
          selectable: true,
          buttonText: {
            today: "Heute",
            month: "Monat",
            week: "Woche",
            day: "Tag",
            list: "Liste"
          },

          // Prevent selection if any date in the range is fully booked.
          selectAllow: function(selectInfo) {
              const fullBlockedDates = computeFullBlockedDates(bookingsData, allComputers);

              let start = new Date(selectInfo.startStr);
              let end = new Date(selectInfo.endStr);

              // Apply +1 correction to start and end dates
              start.setDate(start.getDate() - 1);
              end.setDate(end.getDate() - 2);

              // Loop through the selected range
              while (start <= end) {
                  let dateStr = start.toISOString().split("T")[0];

                  // If any selected date is fully booked, block selection
                  if (fullBlockedDates.includes(dateStr)) {
                      return false; // Prevent selection
                  }

                  start.setDate(start.getDate() + 1);
              }

              return true; // Allow selection if no blocked dates are found
          },
          dayCellDidMount: function(info) {
              const cellDate = info.date.toISOString().split("T")[0];

              // Get bookings that overlap this date
              const dailyBookings = bookingsData.filter(booking => {
                  const startDate = new Date(booking.start_time);
                  const endDate = new Date(booking.end_time);

                  // Subtract 1 day for correct display logic
                  startDate.setDate(startDate.getDate() - 1);
                  endDate.setDate(endDate.getDate() - 1);

                  return cellDate >= startDate.toISOString().split("T")[0] && cellDate <= endDate.toISOString().split("T")[0];
              });

              // Ensure the container exists
              const barContainer = document.createElement("div");
              barContainer.style.position = "absolute"
              barContainer.style.zIndex = "1000";
              barContainer.style.top = "0";
              barContainer.style.left = "0";
              barContainer.style.width = "100%";
              barContainer.style.height = "100%";
              barContainer.style.overflow = "hidden";

              // Assign stacking positions based on consistent PC height
              const pcHeightMap = {
                  "PC-1": 30,
                  "PC-2": 50,
                  "PC-3": 70,
                  "PC-4": 90,
                  "PC-5": 110
              };

              dailyBookings.forEach(booking => {
                  const bookingId = `${booking.computer_name}-${booking.user}`;

                  // Determine the height for the PC
                  const fixedTop = pcHeightMap[booking.computer_name] || 0;

                  // Get the start and end date of the booking
                  const startDate = new Date(booking.start_time);
                  const endDate = new Date(booking.end_time);


                  // Restore the -1 day adjustment
                  startDate.setDate(startDate.getDate() - 1);
                  endDate.setDate(endDate.getDate() - 1);

                  const isFirstDay = cellDate === startDate.toISOString().split("T")[0];
                  const isLastDay = cellDate === endDate.toISOString().split("T")[0];

                  // Create the bar
                  const bar = document.createElement("div");
                  bar.style.position = "absolute";
                  bar.style.top = `${fixedTop}px`;
                  bar.style.left = "0";
                  bar.style.width = "100%";
                  bar.style.height = "12px";
                  bar.style.backgroundColor = "#8e44ad";
                  bar.style.color = "#fff";
                  bar.style.fontSize = "10px";
                  bar.style.lineHeight = "12px";
                  bar.style.padding = "0 4px";
                  bar.style.whiteSpace = "nowrap";
                  bar.style.textOverflow = "ellipsis";
                  bar.style.overflow = "hidden";
                  bar.style.boxShadow = "0 1px 2px rgba(0, 0, 0, 0.5)";
                  bar.style.cursor = "pointer"; // Make it clickable

                  // ✅ Only round corners if it's the first or last day of a booking
                  if (isFirstDay && isLastDay) {
                      bar.style.borderRadius = "4px";
                  } else if (isFirstDay) {
                      bar.style.borderRadius = "4px 0 0 4px";
                  } else if (isLastDay) {
                      bar.style.borderRadius = "0 4px 4px 0";
                  } else {
                      bar.style.borderRadius = "0";
                  }

                  // Only show text on the first day of booking
                  if (isFirstDay) {
                      bar.textContent = `${booking.computer_name} | ${booking.user}`;
                  }

                  // Store booking details in dataset
                  bar.dataset.computer = booking.computer_name;
                  bar.dataset.user = booking.user;
                  bar.dataset.email = booking.email || "N/A";
                  bar.dataset.startTime = booking.start_time;
                  bar.dataset.endTime = booking.end_time;

                  // Add click event for overlay popup
                  bar.addEventListener("click", function () {
                      document.getElementById("overlay").style.display = "flex";

                      const formatDateTime = (dateStr) => {
                          const date = new Date(dateStr);
                          return new Intl.DateTimeFormat("de-DE", {
                              timeZone: "Europe/Berlin",
                              year: "numeric",
                              month: "long",
                              day: "numeric",
                              hour: "2-digit",
                              minute: "2-digit",
                              hour12: false
                          }).format(date).replace(/^.*?, /, ""); // Removes weekday
                      };

                      document.getElementById("overlayName").textContent = `${this.dataset.user}`;
                      document.getElementById("overlayEmail").textContent = `${this.dataset.email}`;
                      document.getElementById("overlayComputer").textContent = `${this.dataset.computer}`;
                      document.getElementById("overlayTime").textContent = `${formatDateTime(this.dataset.startTime)} Uhr bis ${formatDateTime(this.dataset.endTime)} Uhr`;
                  });



                  // Append the bar to the container
                  barContainer.appendChild(bar);
              });

              // Append the container to the cell
              info.el.style.position = "relative";
              info.el.appendChild(barContainer);
          },
          select: function(info) {
              selectedStartDate = info.startStr;
              let endDateObj = new Date(info.end);
              endDateObj.setDate(endDateObj.getDate());
              selectedEndDate = endDateObj.toISOString().split("T")[0];

              const fullBlocked = computeFullBlockedDates(bookingsData, allComputers);
              let adjustedEndDate = adjustEndDate(selectedStartDate, selectedEndDate, fullBlocked);
              if (adjustedEndDate !== selectedEndDate) {
                  alert("Your selected range contains fully booked dates. The end date has been adjusted to " + adjustedEndDate + ".");
                  selectedEndDate = adjustedEndDate;
              }

              updateComputerSelect(selectedStartDate, selectedEndDate);
              document.getElementById("start_time").value = selectedStartDate + "T09:00";
              document.getElementById("end_time").value = selectedEndDate + "T17:00";
              document.getElementById("bookingForm").classList.add("active");
              selectedRange = info;
          },
          unselect: function(info) {
              if (selectedRange) {
                  calendar.select(selectedRange.start, selectedRange.end);

                  let newStartDate = new Date(selectedRange.start);
                  newStartDate.setDate(newStartDate.getDate() + 1);

                  document.getElementById("start_time").value = newStartDate.toISOString().split("T")[0] + "T09:00";
                  document.getElementById("end_time").value = selectedRange.end.toISOString().split("T")[0] + "T17:00";
              }
          }
      });

      document.getElementById("start_time").setAttribute("readonly", true);
      document.getElementById("end_time").setAttribute("readonly", true);

      calendar.render();
  }


        // ---------------- Initialization ----------------
        try {
          allComputers = await fetchComputers();
          await fetchBookings();
          let initialFullBlocked = computeFullBlockedDates(bookingsData, allComputers);
          console.log("All computers from DB:", allComputers);
          console.log("Initial Full Blocked Dates:", initialFullBlocked);
          initializeCalendar();
          calendar.refetchEvents();
        } catch (error) {
          console.error("Error during initialization:", error);
        }
        
        // ---------------- Form Submission ----------------
        document.getElementById("bookingForm").addEventListener("submit", function (event) {
          event.preventDefault();
          let bookingData = {
            computer: document.getElementById("pcSelect").value,
            user: document.getElementById("user").value,
            email: document.getElementById("email").value,
            start_time: document.getElementById("start_time").value,
            end_time: document.getElementById("end_time").value
          };
          console.log("Booking Request:", bookingData);
          // Send the booking data to book.php.
          fetch("book.php", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(bookingData)
          })
          .then(response => response.json())
          .then(data => {
            if (data.error) {
              alert("Booking Failed: " + data.error);
            } else {
              alert("Booking Confirmed:\n" + JSON.stringify(data, null, 2));
              // Refresh the bookings data and update calendar events.
              fetchBookings().then(() => {
                let newFullBlocked = computeFullBlockedDates(bookingsData, allComputers);
                calendar.refetchEvents();
              });
            }
          })
          .catch(error => console.error("Error:", error))
          .finally(() => {
            document.getElementById("bookingForm").reset();
            document.getElementById("bookingForm").classList.remove("active");
          });
        });
      });
    </script>
  </body>
  </html>